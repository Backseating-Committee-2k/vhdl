#include <linux/module.h>

#include <linux/cdev.h>

#include <linux/pci.h>

#include "bss2k_ioctl.h"

#define REG_STATUS      0
#define REG_CONTROL     1
#define REG_INT_STATUS  2
#define REG_INT_MASK    3
#define REG_MAPPING     16

/* emulated CPU has 24 bits, we're using 2 MB pages for mapping, so 3 bits
 * page number and 21 bits page offset */
#define ADDRESS_WIDTH   24
#define MAPPING_BITS    21
#define MAPPING_SIZE    (1 << MAPPING_BITS)
#define NUM_MAPPINGS    (1 << (ADDRESS_WIDTH - MAPPING_BITS))

/* status register */
#define STS_RUNNING             (1 << 0)
#define STS_MAPPING_ERROR       (1 << 1)

/* control register */
#define CTL_RESET               (1 << 0)

/* interrupt registers */
#define INT_HALTED		(1 << 0)

struct bss2k_priv
{
	/* user-visible character device */
	struct cdev cdev;

	/* user visible device */
	struct device *dev;

	/* BAR 2 (registers) mapping */
	u64 volatile *reg;

	/* emulator memory (host pointers) */
	void *host_mem[NUM_MAPPINGS];

	/* emulator memory (DMA descriptors) */
	dma_addr_t host_mem_dma[NUM_MAPPINGS];
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

	filp->private_data = priv;

	return 0;
}

static ssize_t bss2k_read(
		struct file *filp,
		char __user *buf,
		size_t count,
		loff_t *pos)
{
	struct bss2k_priv *const priv = filp->private_data;

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
	struct bss2k_priv *const priv = filp->private_data;

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

static long bss2k_ioctl(
		struct file *filp,
		unsigned int cmd,
		unsigned long arg)
{
	struct bss2k_priv *priv = filp->private_data;

	u64 val = 0;

	if(_IOC_DIR(cmd) & _IOC_WRITE)
	{
		u64 const __user *src = (u64 const __user *)arg;
		if(!src)
			return -EINVAL;
		if(copy_from_user(&val, src, sizeof val))
			return -EFAULT;
	}

	switch(cmd)
	{
	case BSS2K_IOC_RESET:
		priv->reg[REG_CONTROL] |= CTL_RESET;
		break;
	case BSS2K_IOC_START_CPU:
		priv->reg[REG_CONTROL] &= ~CTL_RESET;
		break;
	case BSS2K_IOC_READ_STATUS:
		val = priv->reg[REG_STATUS];
		break;
	case BSS2K_IOC_READ_CONTROL:
		val = priv->reg[REG_CONTROL];
		break;
	case BSS2K_IOC_READ_INTSTS:
		val = priv->reg[REG_INT_STATUS];
		break;
	case BSS2K_IOC_READ_INTMASK:
		val = priv->reg[REG_INT_MASK];
		break;
	case BSS2K_IOC_WRITE_CONTROL:
		priv->reg[REG_CONTROL] = val;
		break;
	case BSS2K_IOC_WRITE_INTMASK:
		priv->reg[REG_INT_MASK] = val;
		break;
	default:
		return -EINVAL;
	}

	if(_IOC_DIR(cmd) & _IOC_READ)
	{
		u64 __user *dst = (u64 __user *)arg;
		if(!dst)
			return -EINVAL;
		if(copy_to_user(dst, &val, sizeof val))
			return -EFAULT;
	}

	return 0;
};

static struct file_operations const bss2k_fops =
{
	.owner = THIS_MODULE,
	.llseek = default_llseek,
	.open = &bss2k_open,
	.read = &bss2k_read,
	.write = &bss2k_write,
	.unlocked_ioctl = &bss2k_ioctl
};

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

	priv->reg = pcim_iomap(pdev, 2, 256);
	if(priv->reg == 0)
		return -ENODEV;

	/* shut down emulated CPU */
	priv->reg[REG_CONTROL] = CTL_RESET;

	/* disable interrupts */
	priv->reg[REG_INT_MASK] = 0ULL;

	/* 64 bit addressing capable */
	err = dma_set_mask_and_coherent(dev, DMA_BIT_MASK(64));
	if(err < 0)
		/* just suboptimal */
		dev_warn(dev, "could not set up 64 bit DMA mask");

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

	cdev_init(&priv->cdev, &bss2k_fops);

	/* TODO minor numbers */
	err = cdev_add(&priv->cdev, bss2k_driver_data.devt, 1);
	if(err < 0)
		goto fail_cdev_add;

	priv->dev = device_create(
			bss2k_driver_data.class,
			dev,
			bss2k_driver_data.devt,
			priv,
			"bss2k-%u",
			0);
	if(IS_ERR(priv->dev))
	{
		err = PTR_ERR(priv->dev);
		goto fail_device_create;
	}

	return 0;

fail_device_create:
	cdev_del(&priv->cdev);

fail_cdev_add:
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

	/* clear mappings, for safety */
	for(i = 0; i < NUM_MAPPINGS; ++i)
		priv->reg[REG_MAPPING + i] = 0ULL;

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
MODULE_LICENSE("GPL");
MODULE_DEVICE_TABLE(pci, bss2k_ids);
