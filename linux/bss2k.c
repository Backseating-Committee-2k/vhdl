#include <linux/module.h>

#include <linux/pci.h>

static unsigned int const reg_status = 0;
static unsigned int const reg_control = 1;
static unsigned int const reg_int_status = 2;
static unsigned int const reg_int_mask = 3;

static int bss2k_probe(
		struct pci_dev *dev,
		struct pci_device_id const *id)
{
	int err;
	u64 volatile *reg;

	err = pcim_enable_device(dev);
	if(err < 0)
		return err;

	printk(KERN_INFO "BSS2k driver loaded.\n");

	reg = pcim_iomap(dev, 2, 256);
	if(reg == 0)
		return -ENODEV;

	printk(KERN_INFO " registers at %px\n", reg);

	printk(KERN_INFO "  status %llx\n", reg[reg_status]);
	reg[reg_status] = 0;
	printk(KERN_INFO "  write status 0 => %llx\n", reg[reg_status]);
	reg[reg_status] = 1;
	printk(KERN_INFO "  write status 1 => %llx\n", reg[reg_status]);

	printk(KERN_INFO "  control %llx\n", reg[reg_control]);
	reg[reg_control] = 0;
	printk(KERN_INFO "  write control 0 => %llx\n", reg[reg_control]);
	reg[reg_control] = 1;
	printk(KERN_INFO "  write control 1 => %llx\n", reg[reg_control]);

	printk(KERN_INFO "  int_status %llx\n", reg[reg_int_status]);
	reg[reg_int_status] = 0;
	printk(KERN_INFO "  write int_status 0 => %llx\n", reg[reg_int_status]);
	reg[reg_int_status] = 1;
	printk(KERN_INFO "  write int_status 1 => %llx\n", reg[reg_int_status]);

	printk(KERN_INFO "  int_mask %llx\n", reg[reg_int_mask]);
	reg[reg_int_mask] = 0;
	printk(KERN_INFO "  write int_mask 0 => %llx\n", reg[reg_int_mask]);
	reg[reg_int_mask] = 1;
	printk(KERN_INFO "  write int_mask 1 => %llx\n", reg[reg_int_mask]);

	return 0;
}

static void bss2k_remove(
		struct pci_dev *dev)
{
	printk(KERN_INFO "BSS2k driver unloaded.\n");
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
