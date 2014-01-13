require "common"

return run_test({
	elf = "irq",
	max_cycle_count = 128,
	modes = {"step", "run"},
	testpoints = {
		{ TP_USER, 2 },
		{ TP_USER, 0 },
		{ TP_USER, 2 },
		{ TP_USER, 1 },
		{ TP_USER, 2 },
		{ TP_USER, 0 },
		{ TP_USER, 2 },
		{ TP_USER, 1 },
		{ TP_SUCCESS, 0 },
	}
})
