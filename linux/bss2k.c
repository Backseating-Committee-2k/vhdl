#include <linux/module.h>

#include <linux/pci.h>

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
	/* BAR 2 (registers) mapping */
	u64 volatile *reg;

	/* emulator memory (host pointers) */
	void *host_mem[NUM_MAPPINGS];

	/* emulator memory (DMA descriptors) */
	dma_addr_t host_mem_dma[NUM_MAPPINGS];
};

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

	return 0;
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
	return pci_register_driver(&bss2k_driver);
}

static void __exit bss2k_exit(void)
{
	pci_unregister_driver(&bss2k_driver);
}

module_init(bss2k_init);
module_exit(bss2k_exit);

MODULE_AUTHOR("Simon Richter <Simon.Richter@hogyros.de>");
MODULE_DESCRIPTION("BackseatsafeSystem2k FPGA implementation");
MODULE_LICENSE("GPL");
MODULE_DEVICE_TABLE(pci, bss2k_ids);
