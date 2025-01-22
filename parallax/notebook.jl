### A Pluto.jl notebook ###
# v0.20.4

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    #! format: off
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
    #! format: on
end

# ╔═╡ c590dff8-d37a-11ef-3086-2b7f386a3b5f
begin
	using AstroImages, Photometry, PlutoUI

	using RegisterMismatch, RegisterQD
	
	using PythonCall, CondaPkg
	# CondaPkg.add(["numpy", "astroalign"])
	CondaPkg.add_pip("astroalign")
	CondaPkg.add("numpy"; version="<2")
end

# ╔═╡ bc696152-6d87-453a-a214-9c931bee7195
md"""
## Load data
"""

# ╔═╡ 55261a90-15f0-431c-9f60-633d93553f09
img1 = load("./data/20240717T080003_317_Occultation.fits");
#load("./data/9fq_2023-08-28T04-15-41.491500_average_30_stack.fits");

# ╔═╡ 33894a80-1027-476a-a664-929740e8f1d6
img2 = load("./data/20240717T080801_868_Occultation.fits");
#load("./data/tbm_2023-08-28T04-15-41.356000_average_30_stack.fits");

# ╔═╡ 04660a8e-0044-4364-9644-91450569571c
imgs = [img1, img2];

# ╔═╡ fe4e3eba-de90-4451-bc6b-9d7ac5e53286
@bind i Slider(1:2; show_value=true)

# ╔═╡ 750918ef-5c36-46db-9779-13a084f0867a
img = imgs[i]

# ╔═╡ 6e06e0c2-ab61-499d-88bb-f47c7cfae3e7


# ╔═╡ 13a371e4-b8d6-4743-b07c-543c2f355c25
# using ImageFeatures, TestImages, Images, ImageDraw, CoordinateTransformations, Rotations

# ╔═╡ 5946c7cd-70e0-40b2-9fe3-3028c3954a73
# img2 = let
# 	rot = ImageTransformations.recenter(RotMatrix(5pi/6), [size(img1)...] .÷ 2)  # a rotation around the center
# 	tform = rot ∘ Translation(-50, -40)
# 	warp(img1, tform, axes(img1))
# end

# ╔═╡ 5fb66d5c-529e-45f1-9965-cd71d21ac256
features_1 = Features(fastcorners(img1, 12, 0.9))

# ╔═╡ 547b1675-18ab-405f-8ba6-78fcfb4484e7
img1_raw

# ╔═╡ 3b87bccf-924c-4a44-8e15-1f8487007fbd
# ╠═╡ disabled = true
#=╠═╡
sources = extract_sources(PeakMesh(), img_slice)[1:5]
  ╠═╡ =#

# ╔═╡ d4273003-aa16-43af-bca7-f0327378c27d
#=╠═╡
aps = CircularAperture.(sources.y, sources.x, 6)
  ╠═╡ =#

# ╔═╡ 1b556e1b-81c8-4e8e-b314-4e21b89ae316
# let
# 	p = implot(img_slice.data; wcsticks=false, colorbar=false)
# 	# plot!(p, aps; color=:lightgreen, linewidth=3)
# 	xlims!(150, 250)
# 	ylims!(125, 200)
# end

# ╔═╡ f2f082ad-2c9b-4edd-8fda-c348561e34e2
md"""
## Setup
"""

# ╔═╡ 6002866d-98e7-4ac3-b3aa-dad0b4648691
TableOfContents()

# ╔═╡ 34d8d525-1b35-4670-861f-4d634142c780
function to_py(img)
	arr = np.zeros_like(img)
	PyArray(arr; copy=false) .= img
	return arr
end

# ╔═╡ 79227718-7005-42ca-b909-a9c1b3e56a59
# Align img2 onto img1
function align(img2, img1)
	registered_image, footprint = aa.register(
		to_py(img2),
		to_py(img1);
		detection_sigma = 3,
		# min_area = 4,
		# max_control_points = 7,
	)
	return shareheader(img2, PyArray(registered_image))
end

# ╔═╡ 8434a6a2-50d6-475d-aac7-728c1025b36b
function align_frames(imgs)
	movs = []
	fixed = first(imgs)
	push!(movs, fixed)
	# mov_old = first(movs)
	for i in 2:length(imgs)
		mov_new = align(imgs[i], fixed)
		push!(movs, mov_new)
		# mov_old = mov_new
	end
	
	return movs
end

# ╔═╡ 52646480-fc66-461e-aed0-0b1d5b26abb6
imgs_aligned = align_frames([img1, img2]);

# ╔═╡ 80077305-3741-40e1-9292-1d8bbcd9339a
imgs_aligned[i]

# ╔═╡ 44b64fcf-1cfa-4487-b366-c301037622ec
AstroImages.set_clims!(Zscale(; contrast=0.5))

# ╔═╡ bfee5254-3731-4bff-93bb-773ebbffead7
# begin
# 	using BlockRegistration
# 	using RegisterMismatch
# end

# ╔═╡ d7aebdaa-84ef-48c9-a49f-c010cd11d58b
@py begin
	import numpy as np
	import astroalign as aa
end

# ╔═╡ 8be9cfc5-54fa-43d9-ad9f-c69b9b5312e7
CondaPkg.status()

# ╔═╡ 5b0b5e7b-66df-472e-9b27-5aef1979fe08


# ╔═╡ Cell order:
# ╟─bc696152-6d87-453a-a214-9c931bee7195
# ╠═55261a90-15f0-431c-9f60-633d93553f09
# ╠═33894a80-1027-476a-a664-929740e8f1d6
# ╠═04660a8e-0044-4364-9644-91450569571c
# ╠═750918ef-5c36-46db-9779-13a084f0867a
# ╟─fe4e3eba-de90-4451-bc6b-9d7ac5e53286
# ╠═52646480-fc66-461e-aed0-0b1d5b26abb6
# ╠═80077305-3741-40e1-9292-1d8bbcd9339a
# ╠═6e06e0c2-ab61-499d-88bb-f47c7cfae3e7
# ╠═13a371e4-b8d6-4743-b07c-543c2f355c25
# ╠═5946c7cd-70e0-40b2-9fe3-3028c3954a73
# ╠═5fb66d5c-529e-45f1-9965-cd71d21ac256
# ╠═547b1675-18ab-405f-8ba6-78fcfb4484e7
# ╠═3b87bccf-924c-4a44-8e15-1f8487007fbd
# ╠═d4273003-aa16-43af-bca7-f0327378c27d
# ╠═1b556e1b-81c8-4e8e-b314-4e21b89ae316
# ╟─f2f082ad-2c9b-4edd-8fda-c348561e34e2
# ╠═6002866d-98e7-4ac3-b3aa-dad0b4648691
# ╟─8434a6a2-50d6-475d-aac7-728c1025b36b
# ╟─79227718-7005-42ca-b909-a9c1b3e56a59
# ╟─34d8d525-1b35-4670-861f-4d634142c780
# ╠═44b64fcf-1cfa-4487-b366-c301037622ec
# ╠═bfee5254-3731-4bff-93bb-773ebbffead7
# ╠═d7aebdaa-84ef-48c9-a49f-c010cd11d58b
# ╠═8be9cfc5-54fa-43d9-ad9f-c69b9b5312e7
# ╠═5b0b5e7b-66df-472e-9b27-5aef1979fe08
# ╠═c590dff8-d37a-11ef-3086-2b7f386a3b5f
