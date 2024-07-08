### A Pluto.jl notebook ###
# v0.19.43

using Markdown
using InteractiveUtils

# ╔═╡ da289c68-e294-4521-8b6d-22da17da068b
md"""
## Aperture photometry 🔾

Now that we have some science frames to work with, the next step is to begin counting the flux coming from our target system so that we can measure it over time. We will use the [Photomtery.jl](https://github.com/JuliaAstro/Photometry.jl) package which is inspired by other tools like astropy's [`photutils`](https://github.com/astropy/photutils) and C's [`SEP`](https://github.com/kbarbary/sep) library to perform source extraction and photometry. 

!!! note
	More at <https://juliaastro.org/dev/modules/AstroImages/guide/photometry/>
"""

# ╔═╡ aaa88822-1363-4216-9380-478ec37659dc
md"""
Before applying this scheme to all of our frames, let's test it out on a random image (`img_test`) selected from our time series:
"""

# ╔═╡ d4a793cf-f142-42b6-b507-c0fddd49cdae
begin
	# Updates this cell every time the button below is pressed
	new_img
	rand_frame_i = rand(1:length(imgs_sci))
	img_test = imgs_sci[rand_frame_i]
	plot_img(rand_frame_i, img_test)
end;

# ╔═╡ 114c4849-a5e6-403d-8746-c4753251ae1f
msg_background_est = md"""
For more on the specific estimation procedures, we highlight this modified section from the [Photometry.jl documentation](https://juliaastro.org/dev/modules/AstroImages/guide/photometry/#Background-Estimation):


> Estimating backgrounds is an important step in performing photometry. Ideally, we could perfectly describe the background with a scalar value or with some distribution. Unfortunately, it's impossible for us to precisely separate the background and foreground signals. Here, we use mixture of robust statistical estimators and meshing to let us get the spatially varying background from an astronomical photo. Let's show an example Now let's try and estimate the background using estimate_background. First, we'll sigma-clip to try and remove the signals from the stars. Then, the background is broken down into boxes. Within each box, the given statistical estimators get the background value and RMS. By default, we use [`SourceExtractorBackground`](https://juliaastro.org/Photometry.jl/stable/background/estimators/#Photometry.Background.SourceExtractorBackground) and [`StdRMS`](https://juliaastro.org/Photometry.jl/stable/background/estimators/#Photometry.Background.StdRMS). This creates a low-resolution image, which we then need to resize. We can accomplish this using an interpolator, by default a cubic-spline interpolator via ZoomInterpolator. The end result is a smooth estimate of the spatially varying background and background RMS.
""";

# ╔═╡ ca895d37-c7a6-44b9-b2ab-94cdb5db0e7d
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

# ╔═╡ fc04d551-b092-4008-af9b-bd1a68788a13
# Step 1
clipped = sigma_clip(img_test, 1; fill=:clamp)

# ╔═╡ db6eeae6-bf85-4e1a-88c0-25fbec0adb1c
# The size of our mesh in pixels (a square with side length = `box_size`)
box_size = gcd(size(img_test)...)

# ╔═╡ 0a6aba65-31b1-412a-bf11-87affd48fa67
# Steps 2-4: Estimate background, and its uncertainty
bkg_f, bkg_rms_f = estimate_background(clipped, box_size)

# ╔═╡ eca9bb16-e496-402a-bbdb-89c71d736002
md"""
Here we have decided to use a mesh (box) size equal to the greatest common denominator between the dimensions of the image so that a fairly course, but whole number of them will fit nicely over our image. This will allow us to avoid needing to deal with boundary conditions where only part of a cell would fit at the edge of the image. Next, we subtract this background estimate off from our image to produce `subt` below. In practice, this just helps reduce the number of potential sources that might get picked up by our source extraction algorithm.
"""

# ╔═╡ c5cc30de-a9d1-4d59-9e19-16d3054360a3
md"""
### Source extraction

Now that we have an estimate for the background flux in our image, we can pass both to `extract_sources` to detect our sources. This routine uses the [`PeakMesh`](https://juliaastro.org/Photometry.jl/stable/detection/algs/#Photometry.Detection.PeakMesh) source detection algorithm, which grids our image and then picks sources that are above a certain threshold in each box.

By default, each box is 3 x 3  pixels. If the source in the center of this odd-sided box is above `error * nsigma`, then it is identified as a source. For this lab, we have decided to use the master dark frame as our `error` and the default `nsigma=3.0` above the background estimate subtracted science image to define our source criteria. Please feel free to experiment with different criteria to see how the different choices can affect our final list of extracted sources.
"""

# ╔═╡ ab6481b7-915d-43d2-8d58-767a4272ce27
img_dark = load("data/TRANSIT/ut20240325/dark/mgcc3f_2024-03-25T07-10-03.022_DARKFRAMEMEAN.fits");

# ╔═╡ 79c77d70-71f2-44e3-affc-6256b7e14ba1
# Returns list of extracted sources, sorted from strongest to weakest
# by default
sources_all = let
	subt = img_test - bkg_f
	extract_sources(PeakMesh(), subt, img_dark)
end

# ╔═╡ 4f542d9a-368f-4669-b291-7dfa7787c2b4
pixel_left, pixel_right = 700, 1_200;

# ╔═╡ 4ffae25e-610a-4ab7-ba7c-c4019bc941cf
md"""
But which one of these potential candidates is our target star? Based on the visualization of our target's motion earlier, the target looks to travel from about pixel $(pixel_left) to $(pixel_right) in the X direction, so let's filter out all of the targets that don't fit this criteria (and also just take the brightest one in case there are still multiple candidates left):
"""

# ╔═╡ 703862df-619d-42ac-aa88-7f06f1fbd477
sources = let
	candidates = filter(sources_all) do source
		pixel_left ≤ source.y ≤ pixel_right
	end

	# Break any ties
	max_val = maximum(candidates.value)
	filter(candidates) do candidate
		candidate.value == max_val
	end
end

# ╔═╡ 9dc83abf-b014-4b40-a1f7-7d1eb91da027
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

# ╔═╡ Cell order:
# ╠═da289c68-e294-4521-8b6d-22da17da068b
# ╠═ca895d37-c7a6-44b9-b2ab-94cdb5db0e7d
# ╠═aaa88822-1363-4216-9380-478ec37659dc
# ╠═d4a793cf-f142-42b6-b507-c0fddd49cdae
# ╠═114c4849-a5e6-403d-8746-c4753251ae1f
# ╠═fc04d551-b092-4008-af9b-bd1a68788a13
# ╠═db6eeae6-bf85-4e1a-88c0-25fbec0adb1c
# ╠═0a6aba65-31b1-412a-bf11-87affd48fa67
# ╠═eca9bb16-e496-402a-bbdb-89c71d736002
# ╠═c5cc30de-a9d1-4d59-9e19-16d3054360a3
# ╠═79c77d70-71f2-44e3-affc-6256b7e14ba1
# ╠═ab6481b7-915d-43d2-8d58-767a4272ce27
# ╠═4ffae25e-610a-4ab7-ba7c-c4019bc941cf
# ╠═4f542d9a-368f-4669-b291-7dfa7787c2b4
# ╠═703862df-619d-42ac-aa88-7f06f1fbd477
# ╠═9dc83abf-b014-4b40-a1f7-7d1eb91da027
