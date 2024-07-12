### A Pluto.jl notebook ###
# v0.19.43

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ 229bc02c-1e05-416b-8503-be064ba9cb06
md"""
## Aperture photometry 🔾

Now that we have some science frames to work with, the next step is to begin counting the flux coming from our target system so that we can measure it over time. We will use the [Photomtery.jl](https://github.com/JuliaAstro/Photometry.jl) package which is inspired by other tools like astropy's [`photutils`](https://github.com/astropy/photutils) and C's [`SEP`](https://github.com/kbarbary/sep) library to perform source extraction and photometry. 

!!! note
	More at <https://juliaastro.org/dev/modules/AstroImages/guide/photometry/>
"""

# ╔═╡ 6c32d0f8-233c-4822-8392-244af980d893
md"""
Before applying this scheme to all of our frames, let's test it out on a random image (`img_test`) selected from our time series:
"""

# ╔═╡ e83d6373-573e-4c6c-98d4-406defbf51e6
msg_background_est = md"""
For more on the specific estimation procedures, we highlight this modified section from the [Photometry.jl documentation](https://juliaastro.org/dev/modules/AstroImages/guide/photometry/#Background-Estimation):


> Estimating backgrounds is an important step in performing photometry. Ideally, we could perfectly describe the background with a scalar value or with some distribution. Unfortunately, it's impossible for us to precisely separate the background and foreground signals. Here, we use mixture of robust statistical estimators and meshing to let us get the spatially varying background from an astronomical photo. Let's show an example Now let's try and estimate the background using estimate_background. First, we'll sigma-clip to try and remove the signals from the stars. Then, the background is broken down into boxes. Within each box, the given statistical estimators get the background value and RMS. By default, we use [`SourceExtractorBackground`](https://juliaastro.org/Photometry.jl/stable/background/estimators/#Photometry.Background.SourceExtractorBackground) and [`StdRMS`](https://juliaastro.org/Photometry.jl/stable/background/estimators/#Photometry.Background.StdRMS). This creates a low-resolution image, which we then need to resize. We can accomplish this using an interpolator, by default a cubic-spline interpolator via ZoomInterpolator. The end result is a smooth estimate of the spatially varying background and background RMS.
""";

# ╔═╡ eae03ca0-7f27-4775-8dd1-6afc94bdb6f7
md"""
### Background estimation

First, we estimate the background flux (`bkg_f`) using one of Photometry.jl's [standard estimator algorithms](https://juliaastro.org/Photometry.jl/stable/background/estimators/#Photometry.Background.SourceExtractorBackground) to help us separate out the background and foreground signals.

To broadly summarize this estimation process, we:

1. [Sigma clip](https://www.gnu.org/software/gnuastro/manual/html_node/Sigma-clipping.html) our image to try remove bright sources (i.e., outliers).

2. Place a mesh grid over the subtracted image to split it into smaller boxes with size determined by `box_size`.

3. Smooth out the remaining image by taking the "average" flux value within each box. "Average" is in quotes because this can be any statistical estimator we choose. By default, this is the [`SourceExtractorBackground`](https://juliaastro.org/Photometry.jl/stable/background/estimators/#Photometry.Background.SourceExtractorBackground) estimator defined in [Photometry.jl](https://juliaastro.org/Photometry.jl/stable/).

4. Interpolate the smaller, averaged image obtained in the previous step back up to its original size to use as our smooth estimate for the background.


$(msg(msg_background_est))
"""

# ╔═╡ 69f6de0a-9f03-4b26-bb13-c2f1c811c795
md"""
Here we have decided to use a mesh (box) size equal to the greatest common denominator between the dimensions of the image so that a fairly course, but whole number of them will fit nicely over our image. This will allow us to avoid needing to deal with boundary conditions where only part of a cell would fit at the edge of the image. Next, we subtract this background estimate off from our image to produce `subt` below. In practice, this just helps reduce the number of potential sources that might get picked up by our source extraction algorithm.
"""

# ╔═╡ 8d65e1ab-811b-4bb1-9fa6-55e451c64a92
md"""
### Source extraction

Now that we have an estimate for the background flux in our image, we can pass both to `extract_sources` to detect our sources. This routine uses the [`PeakMesh`](https://juliaastro.org/Photometry.jl/stable/detection/algs/#Photometry.Detection.PeakMesh) source detection algorithm, which grids our image and then picks sources that are above a certain threshold in each box.

By default, each box is 3 x 3  pixels. If the source in the center of this odd-sided box is above `error * nsigma`, then it is identified as a source. For this lab, we have decided to use the master dark frame as our `error` and the default `nsigma=3.0` above the background estimate subtracted science image to define our source criteria. Please feel free to experiment with different criteria to see how the different choices can affect our final list of extracted sources.
"""

# ╔═╡ 5dc9ce6d-d449-4be0-9cc5-53877d057baa
# # Returns list of extracted sources, sorted from strongest to weakest
# # by default
# sources_all = let
# 	subt = img_test - bkg_f
# 	extract_sources(PeakMesh(), subt, img_dark)
# end

# ╔═╡ 7ee961d2-80bc-4b74-ae53-dd9050432f14
# img_dark = load("data/TRANSIT/ut20240325/dark/mgcc3f_2024-03-25T07-10-03.022_DARKFRAMEMEAN.fits");

# ╔═╡ d848886a-8a28-4dc3-991c-8cb572175478
# md"""
# But which one of these potential candidates is our target star? Based on the visualization of our target's motion earlier, the target looks to travel from about pixel $(pixel_left) to $(pixel_right) in the X direction, so let's filter out all of the targets that don't fit this criteria (and also just take the brightest one in case there are still multiple candidates left):
# """

# ╔═╡ 40108595-f01f-4886-bf7b-6af6ffec8901
# pixel_left, pixel_right = 700, 1_200;

# ╔═╡ c74b7144-fff5-47f9-909a-99e7c523e0b7
# sources = let
# 	candidates = filter(sources_all) do source
# 		pixel_left ≤ source.y ≤ pixel_right
# 	end

# 	# Break any ties
# 	max_val = maximum(candidates.value)
# 	filter(candidates) do candidate
# 		candidate.value == max_val
# 	end
# end

# ╔═╡ fb2dbcc2-35eb-4463-9eaa-699e63f84901
msg(md"""
!!! tip ""

	`do` blocks are handy ways for breaking up long lines. For example, the above could equivalently be written like this:
	
	```julia
	sources = let
		candidates = filter(source -> pixel_left ≤ source.y ≤ pixel_right, sources_all)
	
		# Break any ties
		max_val = maximum(candidates.value)
		filter(candidate -> candidate.value == max_val, candidates)
	end
	```
"""; title=md"What is this `do` syntax?")

# ╔═╡ f4422d9a-0d54-451e-ae2b-51f6f439826f
md"""
Ok, it looks like there is only one candidate left! Let's place an aperture (`ap`) at this location to see how we did:
"""

# ╔═╡ 754c8301-3b4f-435c-8494-de4c6aef9560
# # Place an aperture with radius 24 px at the source extracted location for visualization purposes
# ap = CircularAperture.(sources.y, sources.x, 24);

# ╔═╡ f60cbf22-d482-440b-be8e-3f522b698187
@bind new_img Button("New frame")

# ╔═╡ 0b297340-8539-4ae7-8af0-e1851ac6ffc3
begin
	# Updates this cell every time the button below is pressed
	new_img
	rand_frame_i = rand(1:length(imgs_sci))
	img_test = imgs_sci[rand_frame_i]
	plot_img(rand_frame_i, img_test)
end;

# ╔═╡ 496fcedd-ebdd-45df-bff5-1051f271c9a9
# Step 1
clipped = sigma_clip(img_test, 1; fill=:clamp)

# ╔═╡ 563d6c2b-10cd-4bcb-b89b-859f4f72db2c
# The size of our mesh in pixels (a square with side length = `box_size`)
box_size = gcd(size(img_test)...)

# ╔═╡ 9507108c-e012-482e-ae3f-0c22afb2cfc7
# Steps 2-4: Estimate background, and its uncertainty
bkg_f, bkg_rms_f = estimate_background(clipped, box_size)

# ╔═╡ 439e3e88-6db7-442a-895c-20a7269521ac
# let
# 	fig = plot_img(rand_frame_i, img_test)
# 	add_shape!(fig, get_shapes(ap)[1])
# 	fig
# end

# ╔═╡ a71cceac-694e-493c-a72b-8f32313bf657
md"""
Alright, it looks like this approach successfully identified our target star! We look next at applying this procedure to all of our frames. Feel free to hit the `New frame` button to verify that this scheme works on other sample science frames.
"""

# ╔═╡ Cell order:
# ╠═229bc02c-1e05-416b-8503-be064ba9cb06
# ╠═eae03ca0-7f27-4775-8dd1-6afc94bdb6f7
# ╠═6c32d0f8-233c-4822-8392-244af980d893
# ╠═0b297340-8539-4ae7-8af0-e1851ac6ffc3
# ╠═e83d6373-573e-4c6c-98d4-406defbf51e6
# ╠═496fcedd-ebdd-45df-bff5-1051f271c9a9
# ╠═563d6c2b-10cd-4bcb-b89b-859f4f72db2c
# ╠═9507108c-e012-482e-ae3f-0c22afb2cfc7
# ╠═69f6de0a-9f03-4b26-bb13-c2f1c811c795
# ╠═8d65e1ab-811b-4bb1-9fa6-55e451c64a92
# ╠═5dc9ce6d-d449-4be0-9cc5-53877d057baa
# ╠═7ee961d2-80bc-4b74-ae53-dd9050432f14
# ╠═d848886a-8a28-4dc3-991c-8cb572175478
# ╠═40108595-f01f-4886-bf7b-6af6ffec8901
# ╠═c74b7144-fff5-47f9-909a-99e7c523e0b7
# ╠═fb2dbcc2-35eb-4463-9eaa-699e63f84901
# ╠═f4422d9a-0d54-451e-ae2b-51f6f439826f
# ╠═754c8301-3b4f-435c-8494-de4c6aef9560
# ╠═f60cbf22-d482-440b-be8e-3f522b698187
# ╠═439e3e88-6db7-442a-895c-20a7269521ac
# ╠═a71cceac-694e-493c-a72b-8f32313bf657
