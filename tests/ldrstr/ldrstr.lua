require "common"

return run_test({
	elf = "ldrstr",
	max_cycle_count = 1000,
	modes = {"step", "run"}
})
