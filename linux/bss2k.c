#include <linux/module.h>

#include <linux/pci.h>

static struct pci_device_id const bss2k_ids[] =
{
	{ PCI_DEVICE(0x1172, 0x1337) },
	{ 0, }
};

static int __init bss2k_init(void)
{
	return 0;
}

static void __exit bss2k_exit(void)
{
	return;
}

module_init(bss2k_init);
module_exit(bss2k_exit);

MODULE_AUTHOR("Simon Richter <Simon.Richter@hogyros.de>");
MODULE_DESCRIPTION("BackseatsafeSystem2k FPGA implementation");
MODULE_LICENSE("GPL");
MODULE_DEVICE_TABLE(pci, bss2k_ids);
