# ==========================================================================
# brandkit: quick test (no Shiny required)
# Run this after devtools::load_all() to verify the pipeline works.
# ==========================================================================

library(ggplot2)

# If running from the package root:
# devtools::load_all(".")

# Or if installed:
# library(brandkit)

# --- After loading, theme_brand() is already the ggplot2 default ---
# No + theme_brand() needed on these plots!

cat("Brand name:", brand_raw()$meta$name, "\n")
cat("Base font:", brand_fonts()$base, "\n")
cat("Primary:", brand_colors()$primary, "\n\n")

# Plot 1 — discrete scale should auto-apply
p1 <- ggplot(iris, aes(Sepal.Length, Sepal.Width, color = Species)) +
  geom_point(size = 3) +
  labs(title = "Auto-themed scatter", subtitle = "No theme_brand() call needed")
print(p1)

# Plot 2 — continuous scale
p2 <- ggplot(faithfuld, aes(waiting, eruptions, fill = density)) +
  geom_tile() +
  scale_fill_brand_c(type = "warm") +
  labs(title = "Sequential palette")
print(p2)

# Plot 3 — dark mode
p3 <- ggplot(mtcars, aes(mpg, wt, color = factor(cyl))) +
  geom_point(size = 3) +
  scale_color_brand_d(mode = "dark") +
  theme_brand(mode = "dark") +
  labs(title = "Dark mode", color = "Cylinders")
print(p3)

# Palette overview
cat("\nDiscrete palette (10 colours):\n")
print(brand_pal_discrete(n = 10))
cat("\nSequential warm (5):\n")
print(brand_pal_seq(n = 5))
cat("\nDiverging (7):\n")
print(brand_pal_div(n = 7))
