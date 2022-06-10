#pragma once

static inline uint32_t min(uint32_t lhs, uint32_t rhs)
{
	return (lhs < rhs) ? lhs : rhs;
}

static inline uint32_t max(uint32_t lhs, uint32_t rhs)
{
	return (lhs > rhs) ? lhs : rhs;
}

static inline uint32_t clamp(uint32_t value, uint32_t lower, uint32_t upper)
{
	return min(max(lower, value), upper);
}
