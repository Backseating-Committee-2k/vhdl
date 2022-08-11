#include <linux/module.h>

#include <linux/cdev.h>

#include <linux/interrupt.h>
#include <linux/poll.h>

#include <linux/pci.h>
#include <linux/pci-p2pdma.h>

#include <linux/dma-buf.h>

#include <linux/bits.h>

#include "bss2k_ioctl.h"

#define REG_STATUS      0
#define REG_CONTROL     1
#define REG_INT_STATUS  2
#define REG_INT_MASK    3
#define REG_TEXTMODE    4
#define REG_MAPPING     16

/* emulated CPU has 24 bits, we're using 2 MB pages for mapping, so 3 bits
 * page number and 21 bits page offset */
#define ADDRESS_WIDTH   24
#define MAPPING_BITS    21
#define MAPPING_SIZE    (1ULL << MAPPING_BITS)
#define NUM_MAPPINGS    (1 << (ADDRESS_WIDTH - MAPPING_BITS))

/* status register */
#define STS_RUNNING             BIT_ULL(0)
#define STS_MAPPING_ERROR       BIT_ULL(1)

/* control register */
#define CTL_RESET               BIT_ULL(0)
#define CTL_UPDATEDISPLAY       BIT_ULL(1)

#define CTL_MASK_RESET          BIT_ULL(32)
#define CTL_MASK_UPDATEDISPLAY  BIT_ULL(33)

/* interrupt registers */
#define INT_HALTED              BIT_ULL(0)

/* aperture is two megabytes */
#define DMA_BUF_TEXTMODE_EMULATION_SIZE	0x200000

struct bss2k_priv
{
	/* hardware PCIe device */
	struct pci_dev *pdev;

	/* user-visible character device */
	struct cdev cdev;

	/* user visible device */
	struct device *user_dev;

	/* BAR 2 (registers) mapping */
	u64 volatile *reg;

	/* emulator memory (host pointers) */
	void *host_mem[NUM_MAPPINGS];

	/* emulator memory (DMA descriptors) */
	dma_addr_t host_mem_dma[NUM_MAPPINGS];

	/* trampoline buffer for textmode (host pointer) */
	void *trampoline_cpu;

	/* trampoline buffer for textmode (DMA descriptor) */
	dma_addr_t trampoline_dma;

	/* IRQ for graphics update */
	int gfx_swap_irq;

	/* IRQ handler bottom half */
	struct tasklet_struct interrupt_bottomhalf;

	/* wait queue */
	struct wait_queue_head waitqueue;

	/* event counter */
	u64 swap_event_count;
};

struct bss2k_file_priv
{
	/* device private data */
	struct bss2k_priv *device_priv;

	/* last seen event counter */
	u64 last_swap_event;
};

static int bss2k_open(
		struct inode *ino,
		struct file *filp)
{
	struct bss2k_priv *const priv =
		container_of(
				ino->i_cdev,
				struct bss2k_priv,
				cdev);

	struct bss2k_file_priv *const file_priv =
		kzalloc(sizeof *file_priv, GFP_KERNEL);
	if(!file_priv)
		return -ENOMEM;

	file_priv->device_priv = priv;
	file_priv->last_swap_event = 0;

	filp->private_data = file_priv;

	return 0;
}

static int bss2k_release(
		struct inode *inode,
		struct file *filp)
{
	struct bss2k_file_priv *const file_priv = filp->private_data;

	kfree(file_priv);

	return 0;
}

static ssize_t bss2k_read(
		struct file *filp,
		char __user *buf,
		size_t count,
		loff_t *pos)
{
	struct bss2k_file_priv *const file_priv = filp->private_data;
	struct bss2k_priv *const priv = file_priv->device_priv;

	size_t const end = 0x1000000;		/* 16 MiB */
	size_t const page_size = 0x200000;	/* 2 MiB */

	size_t const address_mask = end - 1;
	size_t const offset_mask = page_size - 1;
	size_t const page_mask = address_mask & ~offset_mask;

	ssize_t total_read = 0;

	/* limit to end of memory */
	if(*pos + count > end)
		count = end - *pos;

	while(count)
	{
		size_t const current_page = (*pos & page_mask) >> MAPPING_BITS;

		size_t const offset_in_current_page = *pos & offset_mask;
		size_t const remaining_in_current_page =
					page_size - offset_in_current_page;
		size_t const to_copy =
				(count > remaining_in_current_page)
				? remaining_in_current_page
				: count;
		unsigned long const not_copied =
				copy_to_user(
					buf,
					priv->host_mem[current_page] + offset_in_current_page,
					to_copy);
		size_t const copied = (to_copy - not_copied);
		*pos += copied;
		total_read += copied;
		count -= copied;
	}
	return total_read;
}

static ssize_t bss2k_write(
		struct file *filp,
		char const __user *buf,
		size_t count,
		loff_t *pos)
{
	struct bss2k_file_priv *const file_priv = filp->private_data;
	struct bss2k_priv *const priv = file_priv->device_priv;

	size_t const end = 0x1000000;		/* 16 MiB */
	size_t const page_size = 0x200000;	/* 2 MiB */

	size_t const address_mask = end - 1;
	size_t const offset_mask = page_size - 1;
	size_t const page_mask = address_mask & ~offset_mask;

	ssize_t total_written = 0;

	/* limit to end of memory */
	if(*pos + count > end)
		count = end - *pos;

	while(count)
	{
		size_t const current_page = (*pos & page_mask) >> MAPPING_BITS;

		size_t const offset_in_current_page = *pos & offset_mask;
		size_t const remaining_in_current_page =
					page_size - offset_in_current_page;
		size_t const to_copy =
				(count > remaining_in_current_page)
				? remaining_in_current_page
				: count;
		unsigned long const not_copied =
				copy_from_user(
					priv->host_mem[current_page] + offset_in_current_page,
					buf,
					to_copy);
		size_t const copied = (to_copy - not_copied);
		*pos += copied;
		total_written += copied;
		count -= copied;
	}
	if(total_written)
		return total_written;
	if(count)
		return -ENOSPC;
	return 0;
}

static int bss2k_attach_textmode(
		struct dma_buf *buf,
		struct dma_buf_attachment *attachment)
{
	struct bss2k_priv *const priv = buf->priv;

	attachment->priv = priv;

	if(pci_p2pdma_distance_many(priv->pdev, &attachment->dev, 1, false) < 0)
		attachment->peer2peer = false;
	else
		attachment->peer2peer = true;

	return 0;
}

static bool bss2k_map_textmode_p2p(
		struct sg_table *sg,
		struct dma_buf_attachment *attachment,
		enum dma_data_direction direction)
{
	struct bss2k_priv *const priv = attachment->priv;

	int err;

	sg->sgl = pci_p2pmem_alloc_sgl(
			priv->pdev,
			&sg->orig_nents,
			DMA_BUF_TEXTMODE_EMULATION_SIZE);

	if(IS_ERR(sg->sgl))
		goto fail_alloc_sgl;

	err = pci_p2pdma_map_sg(
			attachment->dev,
			sg->sgl,
			1,
			direction);
	if(err < 0)
		goto fail_map_sg;

	return true;

fail_map_sg:
	sg_free_table(sg);

fail_alloc_sgl:
	return false;
}

static struct sg_table *bss2k_map_textmode(
		struct dma_buf_attachment *attachment,
		enum dma_data_direction direction)
{
	struct bss2k_priv *const priv = attachment->priv;
	struct pci_dev *const pdev = priv->pdev;
	struct device *const dev = &pdev->dev;

	int err;
	struct sg_table *sg;

	bool const trampoline_is_set_up = !!priv->trampoline_cpu;

	sg = devm_kmalloc(dev, sizeof *sg, GFP_KERNEL);
	if(!sg)
		goto fail_alloc_sg_table;

	sg->nents = 0;
	sg->orig_nents = 0;

	if(!trampoline_is_set_up &&
			attachment->peer2peer &&
			bss2k_map_textmode_p2p(sg, attachment, direction))
		return sg;

	/* fallback to trampoline buffer */

	attachment->peer2peer = false;

	err = -ENOMEM;

	/* TODO: locking */

	if(!priv->trampoline_cpu)
		priv->trampoline_cpu = dmam_alloc_coherent(
				dev,
				DMA_BUF_TEXTMODE_EMULATION_SIZE,
				&priv->trampoline_dma,
				GFP_KERNEL);

	if(!priv->trampoline_cpu)
		goto fail_alloc_buf;

	if(!trampoline_is_set_up)
		priv->reg[REG_TEXTMODE] = priv->trampoline_dma;

	sg->sgl = devm_kmalloc(dev, sizeof(*sg->sgl), GFP_KERNEL);
	if(!sg->sgl)
		goto fail_alloc_scatterlist;

	sg_init_table(sg->sgl, 1);

	sg_set_buf(&sg->sgl[0], priv->trampoline_cpu, DMA_BUF_TEXTMODE_EMULATION_SIZE);
	sg_dma_address(&sg->sgl[0]) = priv->trampoline_dma;
#ifdef CONFIG_NEED_SG_DMA_LENGTH
	sg_dma_len(&sg->sgl[0]) = DMA_BUF_TEXTMODE_EMULATION_SIZE;
#endif
	sg->nents = 1;

	return sg;

fail_alloc_scatterlist:
	/* buffer is kept for other clients */

fail_alloc_buf:
	devm_kfree(dev, sg);

fail_alloc_sg_table:
	return ERR_PTR(err);
}

void bss2k_unmap_textmode(
		struct dma_buf_attachment *attachment,
		struct sg_table *sg,
		enum dma_data_direction direction)
{
	struct bss2k_priv *const priv = attachment->priv;
	struct pci_dev *const pdev = priv->pdev;
	struct device *const dev = &pdev->dev;

	if(attachment->peer2peer)
		pci_p2pmem_free_sgl(pdev, sg->sgl);
	else
		sg_free_table(sg);
	devm_kfree(dev, sg);
}

static void bss2k_release_textmode(
		struct dma_buf *buf)
{
	return;
}

static struct dma_buf_ops const bss2k_textmode_ops =
{
	.cache_sgt_mapping = true,
	.attach = &bss2k_attach_textmode,
	.map_dma_buf = &bss2k_map_textmode,
	.unmap_dma_buf = &bss2k_unmap_textmode,
	.release = &bss2k_release_textmode
};

static long bss2k_ioctl(
		struct file *filp,
		unsigned int cmd,
		unsigned long arg)
{
	struct bss2k_file_priv *const file_priv = filp->private_data;
	struct bss2k_priv *const priv = file_priv->device_priv;

	union
	{
		u64 as_u64;
		int as_int;
	} val;

	if(_IOC_DIR(cmd) & _IOC_WRITE)
	{
		u64 const __user *src = (u64 const __user *)arg;
		if(!src)
			return -EINVAL;
		if(_IOC_SIZE(cmd) > sizeof val)
			return -EINVAL;
		if(copy_from_user(&val, src, _IOC_SIZE(cmd)))
			return -EFAULT;
	}

	switch(cmd)
	{
	case BSS2K_IOC_RESET:
		priv->reg[REG_INT_MASK] = 0ULL;
		priv->reg[REG_CONTROL] = CTL_MASK_RESET | CTL_RESET;
		break;
	case BSS2K_IOC_START_CPU:
		priv->reg[REG_INT_MASK] = 3ULL;
		priv->reg[REG_CONTROL] = CTL_MASK_RESET | 0;
		break;
	case BSS2K_IOC_READ_STATUS:
		val.as_u64 = priv->reg[REG_STATUS];
		break;
	case BSS2K_IOC_READ_CONTROL:
		val.as_u64 = priv->reg[REG_CONTROL];
		break;
	case BSS2K_IOC_READ_INTSTS:
		val.as_u64 = priv->reg[REG_INT_STATUS];
		break;
	case BSS2K_IOC_READ_INTMASK:
		val.as_u64 = priv->reg[REG_INT_MASK];
		break;
	case BSS2K_IOC_WRITE_CONTROL:
		priv->reg[REG_CONTROL] = val.as_u64;
		break;
	case BSS2K_IOC_WRITE_INTMASK:
		priv->reg[REG_INT_MASK] = val.as_u64;
		break;
	case BSS2K_IOC_GET_TEXTMODE_TEXTURE:
		{
			struct dma_buf_export_info const info =
			{
				.exp_name = KBUILD_MODNAME,
				.owner = THIS_MODULE,
				.ops = &bss2k_textmode_ops,
				.size = DMA_BUF_TEXTMODE_EMULATION_SIZE,
				.flags = O_RDONLY,
				.resv = NULL,
				.priv = priv
			};

			struct dma_buf *const buf = dma_buf_export(&info);

			if(IS_ERR(buf))
			{
				dev_err(&priv->pdev->dev, "cannot dma_buf_export: %ld", PTR_ERR(buf));
				return PTR_ERR(buf);
			}

			val.as_int = dma_buf_fd(buf, O_CLOEXEC);
			if(val.as_int < 0)
			{
				dev_err(&priv->pdev->dev, "cannot dma_buf_fd: %d", val.as_int);
				return val.as_int;
			}
		}
		break;
	default:
		return -EINVAL;
	}

	if(_IOC_DIR(cmd) & _IOC_READ)
	{
		u64 __user *dst = (u64 __user *)arg;
		if(!dst)
			return -EINVAL;
		if(_IOC_SIZE(cmd) > sizeof val)
			return -EINVAL;
		if(copy_to_user(dst, &val, _IOC_SIZE(cmd)))
			return -EFAULT;
	}

	return 0;
};

static __poll_t bss2k_poll(
		struct file *filp,
		struct poll_table_struct *wait)
{
	struct bss2k_file_priv *const file_priv = filp->private_data;
	struct bss2k_priv *const priv = file_priv->device_priv;

	u64 swap_event_count = priv->swap_event_count;

	__poll_t ret = 0;

	poll_wait(filp, &priv->waitqueue, wait);

	if(swap_event_count != file_priv->last_swap_event)
	{
		file_priv->last_swap_event = swap_event_count;
		ret |= POLLIN;
	}

	return ret;
}

static struct file_operations const bss2k_fops =
{
	.owner = THIS_MODULE,
	.llseek = default_llseek,
	.open = &bss2k_open,
	.release = &bss2k_release,
	.read = &bss2k_read,
	.write = &bss2k_write,
	.unlocked_ioctl = &bss2k_ioctl,
	.poll = &bss2k_poll
};

static irqreturn_t bss2k_interrupt(int irq, void *data)
{
	struct pci_dev *const pdev = data;
	struct device *const dev = &pdev->dev;
	struct bss2k_priv *const priv = dev_get_drvdata(dev);

	tasklet_schedule(&priv->interrupt_bottomhalf);

	return IRQ_HANDLED;
}

static void bss2k_interrupt_bottomhalf(unsigned long data)
{
	struct bss2k_priv *const priv = (struct bss2k_priv *)data;

	++priv->swap_event_count;

	wake_up(&priv->waitqueue);
}

static struct
{
	/* TODO clean up */
	dev_t devt;

	/* class */
	struct class *class;
} bss2k_driver_data;

static int bss2k_probe(
		struct pci_dev *pdev,
		struct pci_device_id const *id)
{
	struct device *const dev = &pdev->dev;

	int i;
	int err;
	struct bss2k_priv *priv;

	err = pcim_enable_device(pdev);
	if(err < 0)
		return err;

	priv = devm_kzalloc(dev, sizeof *priv, GFP_KERNEL);
	if(!priv)
		return -ENOMEM;

	dev_set_drvdata(dev, priv);

	priv->pdev = pdev;

	/* 64 bit addressing capable */
	err = dma_set_mask_and_coherent(dev, DMA_BIT_MASK(64));
	if(err < 0)
		/* just suboptimal */
		dev_warn(dev, "could not set up 64 bit DMA mask");

	pci_set_master(pdev);

	err = pci_p2pdma_add_resource(pdev, 0, 0, 0);
	if(err < 0)
		return err;

	priv->reg = pcim_iomap(pdev, 2, 256);
	if(priv->reg == 0)
		return -ENODEV;

	/* shut down emulated CPU */
	priv->reg[REG_CONTROL] = CTL_MASK_RESET|CTL_RESET;

	/* disable interrupts */
	priv->reg[REG_INT_MASK] = 0ULL;

	for(i = 0; i < NUM_MAPPINGS; ++i)
	{
		priv->host_mem[i] = dmam_alloc_coherent(dev,
				MAPPING_SIZE,
				&priv->host_mem_dma[i],
				GFP_KERNEL);
		if(!priv->host_mem[i])
			return -ENOMEM;
	}

	for(i = 0; i < NUM_MAPPINGS; ++i)
		priv->reg[REG_MAPPING + i] = priv->host_mem_dma[i];

	if(priv->reg[REG_STATUS] & STS_MAPPING_ERROR)
	{
		dev_err(dev, "status still shows mapping error "
				"after configuration");
		return -ENODEV;
	}

	init_waitqueue_head(&priv->waitqueue);
	priv->swap_event_count = 0;

	tasklet_init(
			&priv->interrupt_bottomhalf,
			&bss2k_interrupt_bottomhalf,
			(unsigned long)priv);

	err = pci_alloc_irq_vectors(pdev, 1, 4, PCI_IRQ_ALL_TYPES);
	if(err < 0)
		goto fail_alloc_irq_vectors;

	priv->gfx_swap_irq = pci_irq_vector(pdev, 0);

	err = devm_request_irq(
			dev,
			priv->gfx_swap_irq,
			&bss2k_interrupt,
			IRQF_SHARED,
			"bss2k",
			pdev);
	if(err < 0)
		goto fail_request_irq;

	cdev_init(&priv->cdev, &bss2k_fops);

	/* TODO minor numbers */
	err = cdev_add(&priv->cdev, bss2k_driver_data.devt, 1);
	if(err < 0)
		goto fail_cdev_add;

	priv->user_dev = device_create(
			bss2k_driver_data.class,
			dev,
			bss2k_driver_data.devt,
			priv,
			"bss2k-%u",
			0);
	if(IS_ERR(priv->user_dev))
	{
		err = PTR_ERR(priv->user_dev);
		goto fail_device_create;
	}

	return 0;

fail_device_create:
	cdev_del(&priv->cdev);

fail_cdev_add:
	devm_free_irq(dev, priv->gfx_swap_irq, priv);

fail_request_irq:
	pci_free_irq_vectors(pdev);

fail_alloc_irq_vectors:
	return err;
}

static void bss2k_remove(
		struct pci_dev *pdev)
{
	struct device *const dev = &pdev->dev;
	struct bss2k_priv *const priv = dev_get_drvdata(dev);

	unsigned int i;

	/* shut down emulated CPU */
	priv->reg[REG_CONTROL] = CTL_RESET;

	/* disable interrupts */
	priv->reg[REG_INT_MASK] = 0ULL;

	devm_free_irq(dev, priv->gfx_swap_irq, priv);
	pci_free_irq_vectors(pdev);

	/* clear mappings, for safety */
	for(i = 0; i < NUM_MAPPINGS; ++i)
		priv->reg[REG_MAPPING + i] = 0ULL;

	/* disable textmode trampoline */
	priv->reg[REG_TEXTMODE] = 0ULL;

	/// TODO cleanup
	device_destroy(
			bss2k_driver_data.class,
			bss2k_driver_data.devt);

	cdev_del(&priv->cdev);

	/* iomap, kmalloc, enable_device are handled by managed device
	 * framework, nothing more to do here.
	 */
}

static struct pci_device_id const bss2k_ids[] =
{
	{ PCI_DEVICE(0x1172, 0x1337) },
	{ 0, }
};

static struct pci_driver bss2k_driver =
{
	.name = "bss2k",
	.id_table = bss2k_ids,
	.probe = bss2k_probe,
	.remove = bss2k_remove,
};

static int __init bss2k_init(void)
{
	int err;

	bss2k_driver_data.class = class_create(THIS_MODULE, "bss2k");
	if(IS_ERR(bss2k_driver_data.class))
	{
		err = PTR_ERR(bss2k_driver_data.class);
		goto err_class;
	}

	err = alloc_chrdev_region(&bss2k_driver_data.devt, 0, 1, "bss2k");
	if(err < 0)
		goto err_chrdev_region;

	err = pci_register_driver(&bss2k_driver);
	if(err < 0)
		goto err_register_driver;

	return 0;

	//pci_unregister_driver(&bss2k_driver);

err_register_driver:
	unregister_chrdev_region(bss2k_driver_data.devt, 1);

err_chrdev_region:
	class_destroy(bss2k_driver_data.class);

err_class:
	return err;
}

static void __exit bss2k_exit(void)
{
	pci_unregister_driver(&bss2k_driver);
	unregister_chrdev_region(bss2k_driver_data.devt, 1);
	class_destroy(bss2k_driver_data.class);
}

module_init(bss2k_init);
module_exit(bss2k_exit);

MODULE_AUTHOR("Simon Richter <Simon.Richter@hogyros.de>");
MODULE_DESCRIPTION("BackseatsafeSystem2k FPGA implementation");
MODULE_IMPORT_NS(DMA_BUF);
MODULE_LICENSE("GPL");
MODULE_DEVICE_TABLE(pci, bss2k_ids);
