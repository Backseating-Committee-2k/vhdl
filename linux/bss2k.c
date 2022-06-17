#include <linux/module.h>

#include <linux/pci.h>

static unsigned int const reg_status = 0;
static unsigned int const reg_control = 1;
static unsigned int const reg_int_status = 2;
static unsigned int const reg_int_mask = 3;
static unsigned int const reg_mapping = 16;

static int bss2k_probe(
		struct pci_dev *dev,
		struct pci_device_id const *id)
{
	int err;
	u64 volatile *reg;

	err = pcim_enable_device(dev);
	if(err < 0)
		return err;

	reg = pcim_iomap(dev, 2, 256);
	if(reg == 0)
		return -ENODEV;

	return 0;
}

static void bss2k_remove(
		struct pci_dev *dev)
{
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
