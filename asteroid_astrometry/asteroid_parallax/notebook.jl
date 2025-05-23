### A Pluto.jl notebook ###
# v0.20.6

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    #! format: off
    return quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
    #! format: on
end

# ╔═╡ 50f77772-c419-4ad7-b9d6-12554302a518
using DynamicQuantities

# ╔═╡ 1f68afec-5916-4fcf-905a-f83a42bdf09b
using EphemerisSources, DataFramesMeta

# ╔═╡ db72ee5e-070b-4dff-b3b6-8b9915ed7b3e
begin
	# Notebook
	using PlutoUI
	using MarkdownLiteral: @mdx
	
	# Viz
	using AstroImages, PlutoPlotly
	AstroImages.set_cmap!(:cividis)
	
	# Analysis
	using CoordinateTransformations, ImageTransformations, LinearAlgebra, OrderedCollections
end

# ╔═╡ 75d03ef4-d8b2-11ef-076a-058846f3b6ba
@mdx """
<h1>Parallax Lab 👥</h1>

!!! note " "
	In this lab we will estimate the distance to a near-Earth object (NEO) based on its measured parallax. For more on taking these types of science observations, see our [Unistellar Planetary Defense page](https://science.unistellar.com/planetary-defense/).

	Having some familiarity in high-level programming languages like Julia or Python will be useful, but not necessary, for following along with the topics covered. At the end of this notebook, you will hopefully have the tools to build your own analysis pipelines for processing general parallax observations, as well as understand the principles behind other astronomical software at a broad level.

!!! warning "Coffee?"
	The first time this notebook runs might take a while (~ couple minutes) because it will download and compile everything for us. This is your chance to take a stretch or grab a nice beverage ☕
"""

# ╔═╡ 4cc6fb84-cefe-4571-850c-762643ff4ffc
md"""
## Using the notebook

!!! note " "
	This lab uses [Pluto.jl](https://plutojl.org/) to share data analysis in a reproducible format. For more information on useage, see the [documentation here](https://plutojl.org/en/docs/). Some of our other [past Unistellar labs](https://www.seti.org/unistellar-education-materials) may also be useful for additional usage examples:

	* [Unistellar Spectroscopy Lab](https://www.seti.org/unistellar-education-materials#Spectroscopy-Lab)
	* [Unistellar Eclipsing Binary Lab](https://www.seti.org/unistellar-education-materials#Eclipsing-Binary-Lab)
	* [Unistellar Asteroid Occultation Lab](https://www.seti.org/unistellar-education-materials#Asteroid-Occultation-Lab)

!!! warning "Interactivity"
	For full interactivity, please click on the `Edit or run this notebook` button in the top right corner. We recommend using the `On your computer` option to download a local copy of this lab. Pluto.jl will handle installation automatically on most platforms (e.g., MacOS, Windows, Linux, ChromeOS).
"""

# ╔═╡ 7d10737f-1691-43e5-891f-118e41cd771a
@mdx """
<h2>Introduction</h2>

!!! note " "
	A nice way to visualize parallax is to look at your thumb or finger at arm's length and blink your eyes back and forth. It should appear to jump back and forth relative to its background. Thanks to the change in perspective afforded by viewing through each of our eyes, we are able to see our finger from a different angle (literally), as in the schematic below:

	$(Resource("https://upload.wikimedia.org/wikipedia/commons/2/2e/Parallax_Example.png"))

	_Source: [JustinWick](https://upload.wikimedia.org/wikipedia/commons/2/2e/Parallax_Example.png)_

	Using a bit of trigonometry, we can then work out the distance to our finger based on how much it appears to shift. We will explore this method more later in the lab.

!!! note " "
	It turns out that the farther away an object is, the smaller its shift will appear to be, until it is so small that our eyes are just not strong enough to discern the shift anymore. This is also why the background appears to be static, and this still holds even if we replace our eyes with the largest telescopes on Earth. One way around this is to place our eyes farther apart (i.e., increase the baseline) to increase the apparent shift of our closer foreground object, and this is exactly what NASA did fairly recently with the [New Horizons](https://science.nasa.gov/mission/new-horizons/) mission, which sent a satellite with a few telescopes onboard out to the furthest reaches of our solar system and beyond.

	On April 22-23, 2020, at a distance of over 4 billion miles from Earth, New Horizons turned on one of its telescopes and took a look at our closest star, [Proxima Centauri](https://imagine.gsfc.nasa.gov/features/cosmic/nearest_star_info.html). What it captured clearly showed a jump relative to its background when compared to the same image taken back on Earth at the same time:

	$(Resource("https://upload.wikimedia.org/wikipedia/commons/e/e2/New_Horizons_Proxima_Centauri_Parallax_Animation.gif"))
	
	_Source: [NASA New Horizons Mission](https://www.nasa.gov/solar-system/nasas-new-horizons-conducts-the-first-interstellar-parallax-experiment/)_

!!! note " "
	For the first time, the parallax method had been used to measure the distance to another star. We do not have 4 billion miles to work with here on Earth, so instead we will use simultaneous observations from two separate ground-based telescopes to measure the distance to a near-Earth asteroid. Keeping track of these distances is a crucial step for detecting, and [potentially diverting](https://science.nasa.gov/mission/dart/), objects that may be on a collision course with Earth.
"""

# ╔═╡ 65d2286a-2786-4f96-8193-d0c4fe77d57a
@mdx """
<h2>Data</h2>

!!! note " "
	In this lab, we will use observations of the near-Earth asteroid [(153591) 2001 SN263](https://en.wikipedia.org/wiki/(153591)_2001_SN263) taken from the following two eVscopes (`OBSERVATORIES`):
"""

# ╔═╡ d12e83b5-8351-44ef-aa4c-b5ace3b4eb39
OBSERVATORIES = OrderedDict(
	"eVscope West" => load(download("https://github.com/icweaver/UCAN/raw/refs/heads/main/asteroid_astrometry/asteroid_parallax/data/nctq52_2022-02-25T19-58-34.991_Science_Defense_103.fits")),
	"eVscope East" => load(download("https://github.com/icweaver/UCAN/raw/refs/heads/main/asteroid_astrometry/asteroid_parallax/data/p4eaaw_2022-02-25T19-58-34.183_Science_Defense_125.fits")),
);

# ╔═╡ b4119602-990d-47b0-8ea5-7f14e17d9e9f
@mdx """
!!! note " "
	and store them into `img_1` and `img_2` for convenience:
"""

# ╔═╡ 94cccd09-ccb9-48d2-b533-246ac0acd405
observatory_1, observatory_2 = keys(OBSERVATORIES)

# ╔═╡ 5523bfd6-4d1c-472f-a028-266b9a891df8
begin
img_1 = OBSERVATORIES[observatory_1];
img_2 = OBSERVATORIES[observatory_2];

# Place images on a common color scale
const ZMIN, ZMAX = let
	lims = Zscale(contrast=0.4).((img_1, img_2))
	minimum(first, lims), maximum(last, lims)
end

AstroImages.set_clims!((ZMIN, ZMAX))
end;

# ╔═╡ 9477e1ef-92e7-49fe-9319-e894ef45852a
@mdx """
**$(observatory_1)**
$(@bind observatory Slider([observatory_1, observatory_2]))
**$(observatory_2)**
"""

# ╔═╡ 10c77d40-dcb9-4620-b9c1-a47a56621a0c
OBSERVATORIES[observatory]

# ╔═╡ 738ef43b-0433-405a-9a63-9074edbfeb14
@mdx """
!!! tip " "
	Associated header file information for the above image.
"""

# ╔═╡ 21afa6af-1df0-4c47-b106-1b9d1e161aa7
header(OBSERVATORIES[observatory])

# ╔═╡ 8bbccbde-4850-4f9d-941a-b163e2133afc
@mdx """
!!! note " "
	Below is a side-by-side comparison with the size of each image (in pixels) displayed to better show the discrepancies. Try zooming or panning around to see how the images compare.
"""

# ╔═╡ 51186ae1-baac-4868-950f-1c9a86d720d8
@mdx """
!!! note " "
	Due to various factors like differences in telescope size, sensors, and pointings, the images are out of sync with each other. To synchronize, we can perform an image alignment procedure. Once this is completed, the background stars should appear essentially motionless when compared with each other, making the parallax shift from the closer-in asteroid more apparent.
"""

# ╔═╡ 867445e3-e2f7-4cca-bf70-26dfcae825dd
@mdx """
<h2>Image alignment</h2>

!!! note " "
	We start by assuming that one image, say `img_2`, can be rotated, translated, and/or scaled to fit onto `img_1`. This type of process is known as an [affine transformation](https://en.wikipedia.org/wiki/Affine_transformation), and it is a common tool for aligning and stacking images.

	We will use the [`kabsch`](https://juliageometry.github.io/CoordinateTransformations.jl/dev/api/#CoordinateTransformations.kabsch) function from [CoordinateTransformations.jl](https://github.com/JuliaGeometry/CoordinateTransformations.jl) to compute this transformation ``\\boldsymbol{(\\phi)}`` for us, given a set of starting (source) points (e.g., point ``\\boldsymbol{p}``) in `img_2` that we would like to map to ending (destination) points (e.g., point ``\\boldsymbol{q}``) in `img_1` as in the schematic below:

	$(Resource("https://juliaimages.org/ImageTransformations.jl/stable/assets/warp_resize.png"))

	_Source: [JuliaImages](https://juliaimages.org/ImageTransformations.jl/stable/#index_image_warping)_

!!! note " "
	Using the comparison plot in the previous section, identify the ``(X, Y)`` pixel coordinates for at least three stars in the source image and corresponding stars in the destination image, respectively. Record these values in the `point_map` variable below, where ``\\boldsymbol{p} = (p_X, p_Y) \\Rightarrow \\boldsymbol{q} = (q_X, q_Y)``.
"""

# ╔═╡ 6fc4ec56-0591-4f61-bdce-43ef796ab3a5
# img_2 points => img_1 points
point_map = (
	[1891, 1341] => [1219, 845],
	[1779, 1177] => [1077, 709],
	[1525, 1039] => [799, 625],
);

# ╔═╡ cf81d974-2bf7-4da0-a781-3519953554ff
tfm = kabsch(last.(point_map) => first.(point_map); scale=true);

# ╔═╡ 6193211b-8ec0-4f88-87df-35247c01353a
@mdx"""
!!! note " "
	For those curious about the linear algebra, the respective linear transformation matrix and translation vector are shown below. They will update in real time in the local version of this notebook each time `point_map` is modified.
"""

# ╔═╡ 568347fb-92a3-4435-8204-80a1a0a1eaef
linear_matrix = tfm.linear

# ╔═╡ 68faa552-2651-4349-9a54-8c9f82e86158
translation_vector = tfm.translation

# ╔═╡ a3a65c1c-a44e-475e-8044-35c453709483
@mdx """
!!! note " "
	We now apply this transformation and stack our images together using the [`warp`](https://juliaimages.org/ImageTransformations.jl/stable/reference/#ImageTransformations.warp) function from [ImageTransformations.jl](https://juliaimages.org/ImageTransformations.jl/stable/). This is analogous to Python's [`warp`](https://scikit-image.org/docs/stable/api/skimage.transform.html#skimage.transform.warp) function in [scikit-image](https://scikit-image.org/).
"""

# ╔═╡ a9960706-4f5b-41e9-8dd4-2fbf24f4daec
img_2w = shareheader(img_2, warp(img_2, tfm, axes(img_1)));

# ╔═╡ 4ed0072f-6159-4893-b21b-e035e51a6689
details(md"What is `shareheader` and `axes`?",
@mdx """
We are using [AstroImages.jl](https://juliaastro.org/dev/modules/AstroImages/) to view and process our images. This allows for fits files to be displayed directly in the notebook, and for interactions with the larger [JuliaImages](https://juliaimages.org/latest/) and [DimensionalData.jl](https://rafaqz.github.io/DimensionalData.jl/stable/) ecosystems.

`AstroImages.shareheader` syncs the header stored in our original image with our `JuliaImages.ImageTransformations.warp`ed image, and `axes` makes sure that the coordinates of our transformed image are shown relative to our `destination` image reference frame of the underlying `DimensionalData`. For more information on this, see [this section of the AstroImages.jl documentation](https://juliaastro.org/dev/modules/AstroImages/manual/dimensions-and-world-coordinates/).
"""
)

# ╔═╡ 5a0b3e26-7271-4b08-aa67-68c3af1421c0
@mdx """
!!! note " "
	With our images now aligned, we can flip back and forth to view the remaining parallax shift from our asteroid.
"""

# ╔═╡ 49b6c887-17fb-45f0-9dff-3aff12e03be5
@mdx """
**$(observatory_1)**
$(@bind img_compare Slider([img_1, img_2w]))
**$(observatory_2) (stacked)**
"""

# ╔═╡ 983a1c03-0344-4905-8cf2-b799003eb94c
img_compare

# ╔═╡ 38d3228b-abf6-435f-b287-ef5b40464bfa
@mdx """
!!! hint
	The asteroid is very small compared to the other point sources in the image. Look closely for an object near the center of both frames that appears to shift.

!!! note " "
	For convenience, we also provide an animated version below, which blinks the images back and forth automatically.

	!!! warning "Note"
		This requires running the notebook locally to view the animation.
"""

# ╔═╡ 13e464bb-30d2-4e6e-b038-69871acbba65
@bind i Clock(max_value=2, repeat=true, start_running=true)

# ╔═╡ 376cb78b-765a-4d8a-aaef-884ec579a2b5
imgs = [img_1, img_2w];

# ╔═╡ cd32b1d0-f455-4822-ad19-6560044d6c4a
imgs[i]

# ╔═╡ 2f9fed6d-0fb0-4a1e-afad-6d7beda95ba1
@mdx """
!!! note " "
	With the asteroid's parallax shift now identified, we turn next to quantifying this motion and estimating a distance based on the parallax method.
"""

# ╔═╡ 8e0e738d-6bdf-4992-bc0e-ea00ea9617ba
@mdx """
<h2>Parallax technique</h2>

!!! note " "
	Revisiting our schematic in the Introduction, let's modify it a bit by annotating the baseline distance ``(b)`` between observers, the distance ``(d)`` to what is being observed, and the apparent parallax shift ``(\\theta)`` along the sky observed between them:

	$(Resource("https://raw.githubusercontent.com/icweaver/UCAN/refs/heads/main/asteroid_astrometry/asteroid_parallax/fig/parallax_diagram.svg"))
	
!!! note " "
	From this model, we can work out the distance ``(d)`` as the following:
	
	```math
	\\begin{align}
	\\tan\\frac{\\theta}{2} &= \\frac{b/2}{d} \\approx \\frac{\\theta}{2} \\text{ [small angle approx.]} \\ , \\\\
	
	d\\text{ (AU)} &\\approx \\frac{b\\text{ km}}{\\theta\\text{ arcsec}}
		\\times \\frac{1\\text{ AU}}{1.496\\times10^{8}\\text{ km}}
		\\times \\frac{206,265''}{1\\text{ rad}} \\\\
	
	&= \\boxed{0.00138 \\times \\frac{b\\text{ km}}{\\theta\\text{ arcsec}}} \\ ,
	\\end{align}
	```

	where ``b`` is measured in kilometers, and ``\\theta`` is measured in arseconds for convenience. We turn next to measuring the parallax shift on sky (``\\theta``).

	!!! tip "Fun fact"
		Due to symmetry, θ/2 is known as the "parallax angle". When an object appears to shift through a parallax angle of 1 arcsecond for a given half-baseline of 1 AU, then by definition the object is 1 [parsec](https://en.wikipedia.org/wiki/Parsec) away.
"""

# ╔═╡ 3e475b77-638c-4bb2-81c6-d7146b72c41f
@mdx """
<h3>Parallax shift</h3>

!!! note " "
	To measure this shift, we can first estimate how many pixels the asteroid appears to move between our two stacked images, and then use the pixel scale of our reference (destination) image to convert to an angle.

	Thanks to our image stacking routine, the correpsonding objects in each image should be in roughly the same spot as we zoom in now. Use the plots below to fill out the coordinates for the asteroid's location in each image:
"""

# ╔═╡ 117751ce-7c9e-461f-9ef9-6310ff0ecfac
@bindname asteroid_px PlutoUI.combine() do Child
	@mdx """
	|image|X|Y
	|------------------|------------------|---|
	|left (destination)|$(Child("dest_x", NumberField(1:size(img_1, 1); default=1017)))|$(Child("dest_y", NumberField(1:size(img_1, 2); default=747)))
	|right (source)|$(Child("src_x", NumberField(1:size(img_2, 1); default=1023)))|$(Child("src_y", NumberField(1:size(img_2, 2); default=747)))
	"""
end

# ╔═╡ 527c1ad3-02d1-4ea5-98b2-d0054f6b5a91
plate_scale = 1.326 # eVscope 2 pixel scale (''/px)

# ╔═╡ aabbcb9d-4310-437f-b7da-03b385916400
θ = let
	ΔX = asteroid_px.dest_x - asteroid_px.src_x
	ΔY = asteroid_px.dest_y - asteroid_px.src_y
	norm((ΔX, ΔY)) * plate_scale
end

# ╔═╡ 43a16d76-7de9-4f19-b1e4-a03457fd1e11
@mdx """
!!! note " "
	Multiplying the Pythagorean distance between these two points by the known [plate scale](https://en.wikipedia.org/wiki/Plate_scale) of our reference image ``($(plate_scale)'' / \\mathrm{pixel})`` then gives a parallax shift of approximately ``\\theta = $(round(θ; digits=2))''``.
"""

# ╔═╡ 864d23ed-d44e-4d3b-887c-73e49a909071
@mdx """
<h3>Parallax distance</h3>

!!! note " "
	We now have everything we need to estimate the distance (d) to our near-Earth asteroid.
"""

# ╔═╡ 6bed5463-00a8-4c73-b0dc-6c7397c7a099
# Baseline (kilometers)
b = 621

# ╔═╡ f4d52a6a-644e-4ff1-861f-a0531c596040
@mdx """
!!! note " "
	These eVscopes were located at a baseline of b = $(b) kilometers apart from each other at the time of observation on February 25th, 2022 at 19:58 UTC.	

	Flipping back and forth, we can see that the field is roughly the same, but unlike the New Horizons example, _all of the objects_ in the frame appear to move, making identifying the apparent parallax shift of the asteroid harder to pick out.
"""

# ╔═╡ 53e5fca6-41ee-4a46-9a41-d9f4e0673c8e
# Distance to asteroid (AU)
d = 0.00138 * b / θ

# ╔═╡ df00e717-2574-4281-9838-1f446960731a
md"""
!!! note " "
	We can do a quick units check with [DynamicQuantities.jl](https://ai.damtp.cam.ac.uk/dynamicquantities/stable/) to verify our results. Note that this will differ slightly from our estimated result because we are internally using a more accurate value for the AU when we make our conversion.
"""

# ╔═╡ 8479dc29-366f-43b2-bfed-2c2b38dd72f8
d_units = (b * u"km") / (θ * u"arcsec") |> us"Constants.au"

# ╔═╡ dd382487-c181-4aad-b9c5-2e9bc422ed01
md"""
### JPL Horizons

!!! note " "
	To query the distance to other asteroids at a given date:
	
	* Edit field 2 in the Horizons System to search for the asteroid by name.
	* Edit field 4 to specify the desired date range to query. For this target, we specified data within three minutes of the `DATE-OBS` field reported in the header of our image files.
	* Click `Generate Ephemeris`.
	* Read off the `delta` field in the data table generated (you may need to scroll down a bit). This will be the distance to the asteroid measured in AU. [See here](https://ssd.jpl.nasa.gov/horizons/manual.html#obsquan) for definitions of the other table column names.

	The associated [Small-Body Database Lookup](https://ssd.jpl.nasa.gov/tools/sbdb_lookup.html#/) tool on this site also provides a 3D simulation of the asteroid's approximate orbit over time (below) and other quick facts.

	![fig1](https://github.com/icweaver/UCAN/blob/main/asteroid_astrometry/asteroid_parallax/fig/orbit_sim.png?raw=true)
"""

# ╔═╡ 7db58c7e-4642-4295-80ae-ef3fd968bf9d
md"""
!!! tip

	For a more automatic approach, we can also use the ephemeris lookup tool in [`EphemerisSources.jl`](https://juliaastro.org/EphemerisSources.jl/docs/stable/)
"""

# ╔═╡ 53512b8f-3120-4f9a-bb5f-ff8aefc96408
# Query 1 minute before and after the parallax observation
df_ephem = ephemeris("153591", "2022-02-25T19:57", "2022-02-25T19:59", "1 minute";
	wrt = "earth",
	units = "AU-D"
) |> DataFrame

# ╔═╡ 7869c86f-52c3-4b3b-be59-b4f7626faf12
# Row 2 has our desired timestamp
d0 = df_ephem[2, [:x, :y, :z]] |> norm

# ╔═╡ 0043f0a6-d309-4527-a554-d37c73c36dfa
accuracy = 100.0 * (d - d0) / d0 # Percent diff

# ╔═╡ 2c5f91b7-4baf-4bbe-8634-c69223916e8f
@mdx """
!!! note " "
	Based on our measurements, we estimate that the asteroid was about **$(round(d; digits=3)) AU** away from the Earth at the time of observation. This is within **$(abs(round(Int, accuracy)))%** of the true distance reported by [JPL](https://ssd.jpl.nasa.gov/horizons/app.html#/)! Try exerimenting with different pixel centers to see how this affects our calculated distance.
"""

# ╔═╡ 9159cb78-6d0e-4c12-8f42-6b8e8316d167
"""
## Wrapping up

!!! note " "
	In this lab, we used simultaneous asteroid observations taken over a large enough baseline to measure the parallax effect. We then used this measurement to estimate the distance to the asteroid to within $(abs(round(Int, accuracy)))%. Not bad for essentially approximating the asteroid's apparent motion by eye!

	What were some additional sources of error that could have contributed to this inaccuracy? What are some ways that we could improve these measurements? After considering, scroll over the section below to view a few potential improvements and extensions to our previous work.

	!!! hint " "
		* **Baseline:** Since ``\\theta`` goes like ``\\frac{b}{d}``, taking measurements over a larger baseline would yield a larger parallax shift that we could then measure to a more accurate degree.
		* **Equatorial coordinates:** We could use a tool like [astrometry.net](https://nova.astrometry.net/) to [plate solve](https://en.wikipedia.org/wiki/Astrometric_solving) our images. This would allow us to directly calculate the ``\\Delta\\text{RA}`` and ``\\Delta\\text{DEC}`` of the asteroid to a high precision instead of relying on pixel coordinates.
		* **Image transformation parameters:** We relied on an affine transformation to stack our images. While flexible, the increased number of parameters relative to simpler transformation schemes can introduce additional error. Perhaps only rotatation and translation would be enough, although this might require using telescopes with comparable plate scales and apertures (like an eVscope!).
		* **Center identification:** Regardless of the stacking scheme and coordinate system chosen, our parallax measurement is only as good as our ability to identify the approximate center of the asteroid in each image. Fitting a point spread function ([PSF](https://en.wikipedia.org/wiki/Point_spread_function)) would be useful for accurately identifying the center coordinates of our asteroid instead of eyeballing it as we did in this lab.

	As of February 1st, 2025, [nearly 40,000 near-Earth asteroids](https://cneos.jpl.nasa.gov/stats/totals.html) have been discovered. That number is expected to rise not only from the last bits of data released in November 2024 by the now concluded [WISE/NEOWISE](https://wise2.ipac.caltech.edu/docs/release/neowise/) mission, but also from the [Near-Earth Object Surveyor](https://science.nasa.gov/mission/neo-surveyor/) telescope that is scheduled for launch in 2028. Keeping track of these asteroids and their measured distances through parallax measurements and other means like [elliptical path fitting](https://www.nasa.gov/solar-system/asteroids/asteroid-fast-facts/) are important components for defending our planet ([NASA](https://science.nasa.gov/planetary-defense/), [ESA](https://www.esa.int/Space_Safety/Planetary_Defence)).
""" |> Markdown.parse

# ╔═╡ e99ae23f-c998-4e09-8d24-5df55b4385ee
@mdx """
<h1>Notebook setup 🔧</h1>
"""

# ╔═╡ a23c40dc-0af3-4c3a-8172-203f58603bbb
TableOfContents()

# ╔═╡ 05b2f9fe-61d2-4640-bbae-78d6d7465597
# Heuristic for keeping plotted images from blowing up
const MAXPIXELS = 10^6

# ╔═╡ 64cf11a7-09ef-459a-98b5-3e5f8a8cd1b5
function trace_hm(img; colorbar_x=0)
	imgv = copy(img)
	# Restriction prescription from AstroImages.jl/Images.jl
	# so plotting doesn't blow up for large images
	while length(eachindex(imgv)) > MAXPIXELS
		imgv = restrict(imgv)
	end
	imgv = permutedims(imgv)
	
	return heatmap(x=dims(imgv, X).val, y=dims(imgv, Y).val, z=imgv.data;
		zmin=ZMIN,
		zmax=ZMAX,
		colorscale = :Cividis,
		colorbar=attr(x=colorbar_x, thickness=10, title="Counts"),
	)
end

# ╔═╡ fdd7bfe6-d4f7-434e-bac3-dc8994a17a6e
function plot_pair(img1, img2)
	loc1, loc2 = keys(OBSERVATORIES)
	# Set up some subplots
	fig = make_subplots(;
		rows = 1,	
		cols = 2,
		shared_xaxes = true,
		shared_yaxes = true,
		column_titles = [loc1, loc2 * " (stacked)"],
	)
	
	# Make the subplot titles a smidgen bit smaller
	update_annotations!(fig, font_size=14)
	
	# Manually place the colorbars so they don't clash
	add_trace!(fig, trace_hm(img1; colorbar_x=0.45), col=1)
	add_trace!(fig, trace_hm(img2; colorbar_x=1), col=2)

	# Keep the images true to size
	update_xaxes!(fig, matches="x", scaleanchor=:y, title="X (pixels)")
	update_yaxes!(fig, matches="y", scaleanchor=:x)

	# Add a shared y-label
	relayout!(fig, Layout(yaxis_title="Y (pixels)"), font_size=10, template="plotly_white", margin=attr(t=20), uirevision=1)

	# Display
	fig
end

# ╔═╡ 2bbcab7e-ee23-4136-b686-5472e61cd117
plot_pair(img_1, img_2)

# ╔═╡ 84c11014-8890-4348-96b6-8e701e458de4
plot_pair(img_1, img_2w)

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
AstroImages = "fe3fc30c-9b16-11e9-1c73-17dabf39f4ad"
CoordinateTransformations = "150eb455-5306-5404-9cee-2592286d6298"
DataFramesMeta = "1313f7d8-7da2-5740-9ea0-a2ca25f37964"
DynamicQuantities = "06fc5a27-2a28-4c7c-a15d-362465fb6821"
EphemerisSources = "858900df-f7ae-402a-aa8c-3e4ef85aa271"
ImageTransformations = "02fcd773-0e25-5acc-982a-7f6622650795"
LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
MarkdownLiteral = "736d6165-7244-6769-4267-6b50796e6954"
OrderedCollections = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
PlutoPlotly = "8e989ff0-3d88-8e9f-f020-2b208a939ff0"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"

[compat]
AstroImages = "~0.5.0"
CoordinateTransformations = "~0.6.4"
DataFramesMeta = "~0.15.4"
DynamicQuantities = "~1.7.0"
EphemerisSources = "~1.0.0"
ImageTransformations = "~0.10.1"
MarkdownLiteral = "~0.1.1"
OrderedCollections = "~1.8.0"
PlutoPlotly = "~0.6.2"
PlutoUI = "~0.7.61"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.11.5"
manifest_format = "2.0"
project_hash = "10e159e999fef03af821b99d672fb5ab3572270e"

[[deps.AbstractFFTs]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "d92ad398961a3ed262d8bf04a1a2b8340f915fef"
uuid = "621f4979-c628-5d54-868e-fcf4e3e8185c"
version = "1.5.0"
weakdeps = ["ChainRulesCore", "Test"]

    [deps.AbstractFFTs.extensions]
    AbstractFFTsChainRulesCoreExt = "ChainRulesCore"
    AbstractFFTsTestExt = "Test"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "6e1d2a35f2f90a4bc7c2ed98079b2ba09c35b83a"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.3.2"

[[deps.Adapt]]
deps = ["LinearAlgebra", "Requires"]
git-tree-sha1 = "50c3c56a52972d78e8be9fd135bfb91c9574c140"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "4.1.1"
weakdeps = ["StaticArrays"]

    [deps.Adapt.extensions]
    AdaptStaticArraysExt = "StaticArrays"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.2"

[[deps.ArnoldiMethod]]
deps = ["LinearAlgebra", "Random", "StaticArrays"]
git-tree-sha1 = "f87e559f87a45bece9c9ed97458d3afe98b1ebb9"
uuid = "ec485272-7323-5ecc-a04f-4719b315124d"
version = "0.1.0"

[[deps.ArrayInterface]]
deps = ["Adapt", "LinearAlgebra"]
git-tree-sha1 = "017fcb757f8e921fb44ee063a7aafe5f89b86dd1"
uuid = "4fba245c-0d91-5ea0-9b3e-6abc04ee57a9"
version = "7.18.0"

    [deps.ArrayInterface.extensions]
    ArrayInterfaceBandedMatricesExt = "BandedMatrices"
    ArrayInterfaceBlockBandedMatricesExt = "BlockBandedMatrices"
    ArrayInterfaceCUDAExt = "CUDA"
    ArrayInterfaceCUDSSExt = "CUDSS"
    ArrayInterfaceChainRulesCoreExt = "ChainRulesCore"
    ArrayInterfaceChainRulesExt = "ChainRules"
    ArrayInterfaceGPUArraysCoreExt = "GPUArraysCore"
    ArrayInterfaceReverseDiffExt = "ReverseDiff"
    ArrayInterfaceSparseArraysExt = "SparseArrays"
    ArrayInterfaceStaticArraysCoreExt = "StaticArraysCore"
    ArrayInterfaceTrackerExt = "Tracker"

    [deps.ArrayInterface.weakdeps]
    BandedMatrices = "aae01518-5342-5314-be14-df237901396f"
    BlockBandedMatrices = "ffab5731-97b5-5995-9138-79e8c1846df0"
    CUDA = "052768ef-5323-5732-b1bb-66c8b64840ba"
    CUDSS = "45b445bb-4962-46a0-9369-b4df9d0f772e"
    ChainRules = "082447d4-558c-5d27-93f4-14fc19e9eca2"
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    GPUArraysCore = "46192b85-c4d5-4398-a991-12ede77f4527"
    ReverseDiff = "37e2e3b7-166d-5795-8a7a-e32c996b4267"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
    StaticArraysCore = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
    Tracker = "9f7883ad-71c0-57eb-9f7f-b5c9e6d3789c"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"
version = "1.11.0"

[[deps.AstroAngles]]
git-tree-sha1 = "0193aaf231612adfa04f1e4187d0370ced0682b4"
uuid = "5c4adb95-c1fc-4c53-b4ea-2a94080c53d2"
version = "0.1.4"

[[deps.AstroImages]]
deps = ["AbstractFFTs", "AstroAngles", "ColorSchemes", "DimensionalData", "FITSIO", "FileIO", "ImageAxes", "ImageBase", "ImageIO", "ImageShow", "MappedArrays", "PlotUtils", "PrecompileTools", "Printf", "RecipesBase", "Statistics", "Tables", "UUIDs", "WCS"]
git-tree-sha1 = "2973b639f56a9aa5563db8be100c8c9a166486af"
uuid = "fe3fc30c-9b16-11e9-1c73-17dabf39f4ad"
version = "0.5.0"

[[deps.AstroTime]]
deps = ["Dates", "EarthOrientation", "ItemGraphs", "LeapSeconds", "MacroTools", "MuladdMacro", "Reexport"]
git-tree-sha1 = "b3217075a2453321b304746f64311e748f9725a7"
uuid = "c61b5328-d09d-5e37-a9a8-0eb41c39009c"
version = "0.7.0"

[[deps.AxisAlgorithms]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "WoodburyMatrices"]
git-tree-sha1 = "01b8ccb13d68535d73d2b0c23e39bd23155fb712"
uuid = "13072b0f-2c55-5437-9ae7-d433b7a33950"
version = "1.1.0"

[[deps.AxisArrays]]
deps = ["Dates", "IntervalSets", "IterTools", "RangeArrays"]
git-tree-sha1 = "16351be62963a67ac4083f748fdb3cca58bfd52f"
uuid = "39de3d68-74b9-583c-8d2d-e117c070f3a9"
version = "0.4.7"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"
version = "1.11.0"

[[deps.BitFlags]]
git-tree-sha1 = "0691e34b3bb8be9307330f88d1a3c3f25466c24d"
uuid = "d1d4a3ce-64b1-5f1a-9ba4-7e7e69966f35"
version = "0.1.9"

[[deps.CEnum]]
git-tree-sha1 = "389ad5c84de1ae7cf0e28e381131c98ea87d54fc"
uuid = "fa961155-64e5-5f13-b03f-caf6b980ea82"
version = "0.5.0"

[[deps.CFITSIO]]
deps = ["CFITSIO_jll"]
git-tree-sha1 = "fc0abb338eb8d90bc186ccf0a47c90825952c950"
uuid = "3b1b4be9-1499-4b22-8d78-7db3344d1961"
version = "1.4.2"

[[deps.CFITSIO_jll]]
deps = ["Artifacts", "JLLWrappers", "LibCURL_jll", "Libdl", "Zlib_jll"]
git-tree-sha1 = "b90d32054fc88f97dd926022f554180e744e4d7d"
uuid = "b3e40c51-02ae-5482-8a39-3ace5868dcf4"
version = "4.4.0+0"

[[deps.CSPICE_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "a51bd1a409e7a95bce12e0620640dc9aaea8a689"
uuid = "07f52509-e9d9-513c-a20d-3b911885bf96"
version = "67.0.0+0"

[[deps.CSV]]
deps = ["CodecZlib", "Dates", "FilePathsBase", "InlineStrings", "Mmap", "Parsers", "PooledArrays", "PrecompileTools", "SentinelArrays", "Tables", "Unicode", "WeakRefStrings", "WorkerUtilities"]
git-tree-sha1 = "deddd8725e5e1cc49ee205a1964256043720a6c3"
uuid = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
version = "0.10.15"

[[deps.Chain]]
git-tree-sha1 = "9ae9be75ad8ad9d26395bf625dea9beac6d519f1"
uuid = "8be319e6-bccf-4806-a6f7-6fae938471bc"
version = "0.6.0"

[[deps.ChainRulesCore]]
deps = ["Compat", "LinearAlgebra"]
git-tree-sha1 = "1713c74e00545bfe14605d2a2be1712de8fbcb58"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.25.1"
weakdeps = ["SparseArrays"]

    [deps.ChainRulesCore.extensions]
    ChainRulesCoreSparseArraysExt = "SparseArrays"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "962834c22b66e32aa10f7611c08c8ca4e20749a9"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.8"

[[deps.ColorSchemes]]
deps = ["ColorTypes", "ColorVectorSpace", "Colors", "FixedPointNumbers", "PrecompileTools", "Random"]
git-tree-sha1 = "26ec26c98ae1453c692efded2b17e15125a5bea1"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.28.0"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "b10d0b65641d57b8b4d5e234446582de5047050d"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.5"

[[deps.ColorVectorSpace]]
deps = ["ColorTypes", "FixedPointNumbers", "LinearAlgebra", "Requires", "Statistics", "TensorCore"]
git-tree-sha1 = "a1f44953f2382ebb937d60dafbe2deea4bd23249"
uuid = "c3611d14-8923-5661-9e6a-0046d554d3a4"
version = "0.10.0"

    [deps.ColorVectorSpace.extensions]
    SpecialFunctionsExt = "SpecialFunctions"

    [deps.ColorVectorSpace.weakdeps]
    SpecialFunctions = "276daf66-3868-5448-9aa4-cd146d93841b"

[[deps.Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "362a287c3aa50601b0bc359053d5c2468f0e7ce0"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.11"

[[deps.CommonMark]]
deps = ["Crayons", "PrecompileTools"]
git-tree-sha1 = "3faae67b8899797592335832fccf4b3c80bb04fa"
uuid = "a80b9123-70ca-4bc0-993e-6e3bcb318db6"
version = "0.8.15"

[[deps.Compat]]
deps = ["TOML", "UUIDs"]
git-tree-sha1 = "8ae8d32e09f0dcf42a36b90d4e17f5dd2e4c4215"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.16.0"
weakdeps = ["Dates", "LinearAlgebra"]

    [deps.Compat.extensions]
    CompatLinearAlgebraExt = "LinearAlgebra"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.1.1+0"

[[deps.ConcurrentUtilities]]
deps = ["Serialization", "Sockets"]
git-tree-sha1 = "d9d26935a0bcffc87d2613ce14c527c99fc543fd"
uuid = "f0e56b4a-5159-44fe-b623-3e5288b988bb"
version = "2.5.0"

[[deps.ConstructionBase]]
git-tree-sha1 = "76219f1ed5771adbb096743bff43fb5fdd4c1157"
uuid = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
version = "1.5.8"
weakdeps = ["IntervalSets", "LinearAlgebra", "StaticArrays"]

    [deps.ConstructionBase.extensions]
    ConstructionBaseIntervalSetsExt = "IntervalSets"
    ConstructionBaseLinearAlgebraExt = "LinearAlgebra"
    ConstructionBaseStaticArraysExt = "StaticArrays"

[[deps.CoordinateTransformations]]
deps = ["LinearAlgebra", "StaticArrays"]
git-tree-sha1 = "a692f5e257d332de1e554e4566a4e5a8a72de2b2"
uuid = "150eb455-5306-5404-9cee-2592286d6298"
version = "0.6.4"

[[deps.Crayons]]
git-tree-sha1 = "249fe38abf76d48563e2f4556bebd215aa317e15"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.1.1"

[[deps.DataAPI]]
git-tree-sha1 = "abe83f3a2f1b857aac70ef8b269080af17764bbe"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.16.0"

[[deps.DataFrames]]
deps = ["Compat", "DataAPI", "DataStructures", "Future", "InlineStrings", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrecompileTools", "PrettyTables", "Printf", "Random", "Reexport", "SentinelArrays", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "fb61b4812c49343d7ef0b533ba982c46021938a6"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.7.0"

[[deps.DataFramesMeta]]
deps = ["Chain", "DataFrames", "MacroTools", "OrderedCollections", "Reexport", "TableMetadataTools"]
git-tree-sha1 = "21a4335f249f8b5f311d00d5e62938b50ccace4e"
uuid = "1313f7d8-7da2-5740-9ea0-a2ca25f37964"
version = "0.15.4"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "1d0a14036acb104d9e89698bd408f63ab58cdc82"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.20"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"
version = "1.11.0"

[[deps.DelimitedFiles]]
deps = ["Mmap"]
git-tree-sha1 = "9e2f36d3c96a820c678f2f1f1782582fcf685bae"
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"
version = "1.9.1"

[[deps.DimensionalData]]
deps = ["Adapt", "ArrayInterface", "ConstructionBase", "DataAPI", "Dates", "Extents", "Interfaces", "IntervalSets", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "PrecompileTools", "Random", "RecipesBase", "SparseArrays", "Statistics", "TableTraits", "Tables"]
git-tree-sha1 = "7723a66edfd3bfff65ec510959b6683f8acfb111"
uuid = "0703355e-b756-11e9-17c0-8b28908087d0"
version = "0.27.9"

    [deps.DimensionalData.extensions]
    DimensionalDataCategoricalArraysExt = "CategoricalArrays"
    DimensionalDataMakie = "Makie"

    [deps.DimensionalData.weakdeps]
    CategoricalArrays = "324d7699-5711-5eae-9e2f-1d82baa6b597"
    Makie = "ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a"

[[deps.DispatchDoctor]]
deps = ["MacroTools", "Preferences"]
git-tree-sha1 = "f311fe66bfe4e38b2f1c8d1081f06920092b57aa"
uuid = "8d63f2c5-f18a-4cf2-ba9d-b3f60fc568c8"
version = "0.4.19"

    [deps.DispatchDoctor.extensions]
    DispatchDoctorChainRulesCoreExt = "ChainRulesCore"
    DispatchDoctorEnzymeCoreExt = "EnzymeCore"

    [deps.DispatchDoctor.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    EnzymeCore = "f151be2c-9106-41f4-ab19-57ee4f262869"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"
version = "1.11.0"

[[deps.DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "2fb1e02f2b635d0845df5d7c167fec4dd739b00d"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.3"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.DynamicQuantities]]
deps = ["DispatchDoctor", "PrecompileTools", "TestItems", "Tricks"]
git-tree-sha1 = "2cf4f27ea6997aabf4b3e3b97355af3d757efd6b"
uuid = "06fc5a27-2a28-4c7c-a15d-362465fb6821"
version = "1.7.0"

    [deps.DynamicQuantities.extensions]
    DynamicQuantitiesLinearAlgebraExt = "LinearAlgebra"
    DynamicQuantitiesMeasurementsExt = "Measurements"
    DynamicQuantitiesScientificTypesExt = "ScientificTypes"
    DynamicQuantitiesUnitfulExt = "Unitful"

    [deps.DynamicQuantities.weakdeps]
    LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
    Measurements = "eff96d63-e80a-5855-80a2-b1b0885c5ab7"
    ScientificTypes = "321657f4-b219-11e9-178b-2701a2544e81"
    Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[[deps.EarthOrientation]]
deps = ["Dates", "DelimitedFiles", "LeapSeconds", "OptionalData", "RemoteFiles"]
git-tree-sha1 = "baf9b839d105f4e116c0fc3c62ee45ba2314b8a5"
uuid = "732a3c5d-d6c0-58bc-adb1-1b51709a25e2"
version = "0.7.3"

[[deps.EphemerisSources]]
deps = ["AstroTime", "EphemerisSourcesBase", "HorizonsAPI", "HorizonsEphemeris", "Reexport", "SPICE", "SPICEBodies", "SPICEKernels"]
git-tree-sha1 = "4252a4bdcd8b2700019d6c324ff58bab950678d2"
uuid = "858900df-f7ae-402a-aa8c-3e4ef85aa271"
version = "1.0.0"

[[deps.EphemerisSourcesBase]]
deps = ["AstroTime", "Dates", "DocStringExtensions", "SPICE", "SPICEApplications"]
git-tree-sha1 = "5dcdc63b69063616f37ce2b6ad5a3c88b12f9170"
uuid = "b8f1d712-e88d-4f2a-8498-e66ce688ee29"
version = "0.2.0"

[[deps.ExceptionUnwrapping]]
deps = ["Test"]
git-tree-sha1 = "d36f682e590a83d63d1c7dbd287573764682d12a"
uuid = "460bff9d-24e4-43bc-9d9f-a8973cb893f4"
version = "0.1.11"

[[deps.Extents]]
git-tree-sha1 = "063512a13dbe9c40d999c439268539aa552d1ae6"
uuid = "411431e0-e8b7-467b-b5e0-f676ba4f2910"
version = "0.1.5"

[[deps.FITSIO]]
deps = ["CFITSIO", "Printf", "Reexport", "Tables"]
git-tree-sha1 = "8b68d078e8ec3660b7e95528f1a888c5222d2fb4"
uuid = "525bcba6-941b-5504-bd06-fd0dc1a4d2eb"
version = "0.17.4"

[[deps.FileIO]]
deps = ["Pkg", "Requires", "UUIDs"]
git-tree-sha1 = "2dd20384bf8c6d411b5c7370865b1e9b26cb2ea3"
uuid = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
version = "1.16.6"
weakdeps = ["HTTP"]

    [deps.FileIO.extensions]
    HTTPExt = "HTTP"

[[deps.FilePathsBase]]
deps = ["Compat", "Dates"]
git-tree-sha1 = "3bab2c5aa25e7840a4b065805c0cdfc01f3068d2"
uuid = "48062228-2e41-5def-b9a4-89aafe57970f"
version = "0.9.24"
weakdeps = ["Mmap", "Test"]

    [deps.FilePathsBase.extensions]
    FilePathsBaseMmapExt = "Mmap"
    FilePathsBaseTestExt = "Test"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"
version = "1.11.0"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "05882d6995ae5c12bb5f36dd2ed3f61c98cbb172"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.5"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"
version = "1.11.0"

[[deps.Giflib_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "6570366d757b50fabae9f4315ad74d2e40c0560a"
uuid = "59f7168a-df46-5410-90c8-f2779963d0ec"
version = "5.2.3+0"

[[deps.HTTP]]
deps = ["Base64", "CodecZlib", "ConcurrentUtilities", "Dates", "ExceptionUnwrapping", "Logging", "LoggingExtras", "MbedTLS", "NetworkOptions", "OpenSSL", "PrecompileTools", "Random", "SimpleBufferStream", "Sockets", "URIs", "UUIDs"]
git-tree-sha1 = "c67b33b085f6e2faf8bf79a61962e7339a81129c"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "1.10.15"

[[deps.HashArrayMappedTries]]
git-tree-sha1 = "2eaa69a7cab70a52b9687c8bf950a5a93ec895ae"
uuid = "076d061b-32b6-4027-95e0-9a2c6f6d7e74"
version = "0.2.0"

[[deps.HorizonsAPI]]
deps = ["DocStringExtensions", "HTTP"]
git-tree-sha1 = "90b5770e75e2bdf97c0d26e3ece69dfebf7c2fbc"
uuid = "c15253bb-5e94-4b8b-9a02-579bb6c8e3ce"
version = "1.1.0"

[[deps.HorizonsEphemeris]]
deps = ["AstroTime", "CSV", "Dates", "DocStringExtensions", "HTTP", "HorizonsAPI", "JSON", "Printf", "SPICE", "SPICEApplications"]
git-tree-sha1 = "2df23f1661f1b0876946141591e9a864a686c78c"
uuid = "05ee1981-f730-42d8-b713-4f42d99733dc"
version = "1.4.0"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "179267cfa5e712760cd43dcae385d7ea90cc25a4"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.5"

[[deps.HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "7134810b1afce04bbc1045ca1985fbe81ce17653"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.5"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "b6d6bfdd7ce25b0f9b2f6b3dd56b2673a66c8770"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.5"

[[deps.ImageAxes]]
deps = ["AxisArrays", "ImageBase", "ImageCore", "Reexport", "SimpleTraits"]
git-tree-sha1 = "e12629406c6c4442539436581041d372d69c55ba"
uuid = "2803e5a7-5153-5ecf-9a86-9b4c37f5f5ac"
version = "0.6.12"

[[deps.ImageBase]]
deps = ["ImageCore", "Reexport"]
git-tree-sha1 = "eb49b82c172811fd2c86759fa0553a2221feb909"
uuid = "c817782e-172a-44cc-b673-b171935fbb9e"
version = "0.1.7"

[[deps.ImageCore]]
deps = ["ColorVectorSpace", "Colors", "FixedPointNumbers", "MappedArrays", "MosaicViews", "OffsetArrays", "PaddedViews", "PrecompileTools", "Reexport"]
git-tree-sha1 = "8c193230235bbcee22c8066b0374f63b5683c2d3"
uuid = "a09fc81d-aa75-5fe9-8630-4744c3626534"
version = "0.10.5"

[[deps.ImageIO]]
deps = ["FileIO", "IndirectArrays", "JpegTurbo", "LazyModules", "Netpbm", "OpenEXR", "PNGFiles", "QOI", "Sixel", "TiffImages", "UUIDs", "WebP"]
git-tree-sha1 = "696144904b76e1ca433b886b4e7edd067d76cbf7"
uuid = "82e4d734-157c-48bb-816b-45c225c6df19"
version = "0.6.9"

[[deps.ImageMetadata]]
deps = ["AxisArrays", "ImageAxes", "ImageBase", "ImageCore"]
git-tree-sha1 = "2a81c3897be6fbcde0802a0ebe6796d0562f63ec"
uuid = "bc367c6b-8a6b-528e-b4bd-a4b897500b49"
version = "0.9.10"

[[deps.ImageShow]]
deps = ["Base64", "ColorSchemes", "FileIO", "ImageBase", "ImageCore", "OffsetArrays", "StackViews"]
git-tree-sha1 = "3b5344bcdbdc11ad58f3b1956709b5b9345355de"
uuid = "4e3cecfd-b093-5904-9786-8bbb286a6a31"
version = "0.3.8"

[[deps.ImageTransformations]]
deps = ["AxisAlgorithms", "CoordinateTransformations", "ImageBase", "ImageCore", "Interpolations", "OffsetArrays", "Rotations", "StaticArrays"]
git-tree-sha1 = "e0884bdf01bbbb111aea77c348368a86fb4b5ab6"
uuid = "02fcd773-0e25-5acc-982a-7f6622650795"
version = "0.10.1"

[[deps.Imath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "0936ba688c6d201805a83da835b55c61a180db52"
uuid = "905a6f67-0a94-5f89-b386-d35d92009cd1"
version = "3.1.11+0"

[[deps.IndirectArrays]]
git-tree-sha1 = "012e604e1c7458645cb8b436f8fba789a51b257f"
uuid = "9b13fd28-a010-5f03-acff-a1bbcff69959"
version = "1.0.0"

[[deps.Inflate]]
git-tree-sha1 = "d1b1b796e47d94588b3757fe84fbf65a5ec4a80d"
uuid = "d25df0c9-e2be-5dd7-82c8-3ad0b3e990b9"
version = "0.1.5"

[[deps.InlineStrings]]
git-tree-sha1 = "6a9fde685a7ac1eb3495f8e812c5a7c3711c2d5e"
uuid = "842dd82b-1e85-43dc-bf29-5d0ee9dffc48"
version = "1.4.3"

    [deps.InlineStrings.extensions]
    ArrowTypesExt = "ArrowTypes"
    ParsersExt = "Parsers"

    [deps.InlineStrings.weakdeps]
    ArrowTypes = "31f734f8-188a-4ce0-8406-c8a06bd891cd"
    Parsers = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"
version = "1.11.0"

[[deps.Interfaces]]
git-tree-sha1 = "331ff37738aea1a3cf841ddf085442f31b84324f"
uuid = "85a1e053-f937-4924-92a5-1367d23b7b87"
version = "0.3.2"

[[deps.Interpolations]]
deps = ["Adapt", "AxisAlgorithms", "ChainRulesCore", "LinearAlgebra", "OffsetArrays", "Random", "Ratios", "Requires", "SharedArrays", "SparseArrays", "StaticArrays", "WoodburyMatrices"]
git-tree-sha1 = "88a101217d7cb38a7b481ccd50d21876e1d1b0e0"
uuid = "a98d9a8b-a2ab-59e6-89dd-64a1c18fca59"
version = "0.15.1"
weakdeps = ["Unitful"]

    [deps.Interpolations.extensions]
    InterpolationsUnitfulExt = "Unitful"

[[deps.IntervalSets]]
git-tree-sha1 = "dba9ddf07f77f60450fe5d2e2beb9854d9a49bd0"
uuid = "8197267c-284f-5f27-9208-e0e47529a953"
version = "0.7.10"
weakdeps = ["Random", "RecipesBase", "Statistics"]

    [deps.IntervalSets.extensions]
    IntervalSetsRandomExt = "Random"
    IntervalSetsRecipesBaseExt = "RecipesBase"
    IntervalSetsStatisticsExt = "Statistics"

[[deps.InvertedIndices]]
git-tree-sha1 = "6da3c4316095de0f5ee2ebd875df8721e7e0bdbe"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.3.1"

[[deps.ItemGraphs]]
deps = ["LightGraphs"]
git-tree-sha1 = "e363e8bbeb44dc32c711a9c3f7e7323601050727"
uuid = "d5eda45b-7e79-5788-9687-2c6ab7b96158"
version = "0.4.0"

[[deps.IterTools]]
git-tree-sha1 = "42d5f897009e7ff2cf88db414a389e5ed1bdd023"
uuid = "c8e1da08-722c-5040-9ed9-7db0dc04731e"
version = "1.10.0"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JLLWrappers]]
deps = ["Artifacts", "Preferences"]
git-tree-sha1 = "a007feb38b422fbdab534406aeca1b86823cb4d6"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.7.0"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "31e996f0a15c7b280ba9f76636b3ff9e2ae58c9a"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.4"

[[deps.JpegTurbo]]
deps = ["CEnum", "FileIO", "ImageCore", "JpegTurbo_jll", "TOML"]
git-tree-sha1 = "fa6d0bcff8583bac20f1ffa708c3913ca605c611"
uuid = "b835a17e-a41a-41e7-81f0-2f016b05efe0"
version = "0.1.5"

[[deps.JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "eac1206917768cb54957c65a615460d87b455fc1"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "3.1.1+0"

[[deps.LERC_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "aaafe88dccbd957a8d82f7d05be9b69172e0cee3"
uuid = "88015f11-f218-50d7-93a8-a6af411a945d"
version = "4.0.1+0"

[[deps.LaTeXStrings]]
git-tree-sha1 = "dda21b8cbd6a6c40d9d02a73230f9d70fed6918c"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.4.0"

[[deps.LazyModules]]
git-tree-sha1 = "a560dd966b386ac9ae60bdd3a3d3a326062d3c3e"
uuid = "8cdb02fc-e678-4876-92c5-9defec4f444e"
version = "0.3.1"

[[deps.LeapSeconds]]
deps = ["Dates"]
git-tree-sha1 = "0e5be6875ee72468bc12221d32ba1021c5d224fe"
uuid = "2f5f767c-a11e-5269-a972-637d4b97c32d"
version = "1.1.0"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.4"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "8.6.0+0"

[[deps.LibGit2]]
deps = ["Base64", "LibGit2_jll", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"
version = "1.11.0"

[[deps.LibGit2_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll"]
uuid = "e37daf67-58a4-590a-8e99-b0245dd2ffc5"
version = "1.7.2+0"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.11.0+1"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"
version = "1.11.0"

[[deps.Libgcrypt_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgpg_error_jll"]
git-tree-sha1 = "8be878062e0ffa2c3f67bb58a595375eda5de80b"
uuid = "d4300ac3-e22c-5743-9152-c294e39db1e4"
version = "1.11.0+0"

[[deps.Libglvnd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll", "Xorg_libXext_jll"]
git-tree-sha1 = "ff3b4b9d35de638936a525ecd36e86a8bb919d11"
uuid = "7e76a0d4-f3c7-5321-8279-8d96eeed0f29"
version = "1.7.0+0"

[[deps.Libgpg_error_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "df37206100d39f79b3376afb6b9cee4970041c61"
uuid = "7add5ba3-2f88-524e-9cd5-f83b8a55f7b8"
version = "1.51.1+0"

[[deps.Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "be484f5c92fad0bd8acfef35fe017900b0b73809"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.18.0+0"

[[deps.Libtiff_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "LERC_jll", "Libdl", "XZ_jll", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "4ab7581296671007fc33f07a721631b8855f4b1d"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.7.1+0"

[[deps.LightGraphs]]
deps = ["ArnoldiMethod", "DataStructures", "Distributed", "Inflate", "LinearAlgebra", "Random", "SharedArrays", "SimpleTraits", "SparseArrays", "Statistics"]
git-tree-sha1 = "432428df5f360964040ed60418dd5601ecd240b6"
uuid = "093fc24a-ae57-5d10-9952-331d41423f4d"
version = "1.3.5"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
version = "1.11.0"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"
version = "1.11.0"

[[deps.LoggingExtras]]
deps = ["Dates", "Logging"]
git-tree-sha1 = "f02b56007b064fbfddb4c9cd60161b6dd0f40df3"
uuid = "e6f89c97-d47a-5376-807f-9c37f3926c36"
version = "1.1.0"

[[deps.MIMEs]]
git-tree-sha1 = "1833212fd6f580c20d4291da9c1b4e8a655b128e"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "1.0.0"

[[deps.MacroTools]]
git-tree-sha1 = "72aebe0b5051e5143a079a4685a46da330a40472"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.15"

[[deps.MappedArrays]]
git-tree-sha1 = "2dab0221fe2b0f2cb6754eaa743cc266339f527e"
uuid = "dbb5928d-eab1-5f90-85c2-b9b0edb7c900"
version = "0.4.2"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"
version = "1.11.0"

[[deps.MarkdownLiteral]]
deps = ["CommonMark", "HypertextLiteral"]
git-tree-sha1 = "0d3fa2dd374934b62ee16a4721fe68c418b92899"
uuid = "736d6165-7244-6769-4267-6b50796e6954"
version = "0.1.1"

[[deps.MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "MozillaCACerts_jll", "NetworkOptions", "Random", "Sockets"]
git-tree-sha1 = "c067a280ddc25f196b5e7df3877c6b226d390aaf"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.1.9"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.6+0"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "ec4f7fbeab05d7747bdf98eb74d130a2a2ed298d"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.2.0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"
version = "1.11.0"

[[deps.MosaicViews]]
deps = ["MappedArrays", "OffsetArrays", "PaddedViews", "StackViews"]
git-tree-sha1 = "7b86a5d4d70a9f5cdf2dacb3cbe6d251d1a61dbe"
uuid = "e94cdb99-869f-56ef-bcf0-1ae2bcbe0389"
version = "0.3.4"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2023.12.12"

[[deps.MuladdMacro]]
git-tree-sha1 = "cac9cc5499c25554cba55cd3c30543cff5ca4fab"
uuid = "46d2c3a1-f734-5fdb-9937-b9b9aeba4221"
version = "0.2.4"

[[deps.Netpbm]]
deps = ["FileIO", "ImageCore", "ImageMetadata"]
git-tree-sha1 = "d92b107dbb887293622df7697a2223f9f8176fcd"
uuid = "f09324ee-3d7c-5217-9330-fc30815ba969"
version = "1.1.1"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.OffsetArrays]]
git-tree-sha1 = "5e1897147d1ff8d98883cda2be2187dcf57d8f0c"
uuid = "6fe1bfb0-de20-5000-8ca7-80f57d26f881"
version = "1.15.0"
weakdeps = ["Adapt"]

    [deps.OffsetArrays.extensions]
    OffsetArraysAdaptExt = "Adapt"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.27+1"

[[deps.OpenEXR]]
deps = ["Colors", "FileIO", "OpenEXR_jll"]
git-tree-sha1 = "97db9e07fe2091882c765380ef58ec553074e9c7"
uuid = "52e1d378-f018-4a11-a4be-720524705ac7"
version = "0.3.3"

[[deps.OpenEXR_jll]]
deps = ["Artifacts", "Imath_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "8292dd5c8a38257111ada2174000a33745b06d4e"
uuid = "18a262bb-aa17-5467-a713-aee519bc75cb"
version = "3.2.4+0"

[[deps.OpenSSL]]
deps = ["BitFlags", "Dates", "MozillaCACerts_jll", "OpenSSL_jll", "Sockets"]
git-tree-sha1 = "38cb508d080d21dc1128f7fb04f20387ed4c0af4"
uuid = "4d8831e6-92b7-49fb-bdf8-b643e874388c"
version = "1.4.3"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "a9697f1d06cc3eb3fb3ad49cc67f2cfabaac31ea"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "3.0.16+0"

[[deps.OptionalData]]
git-tree-sha1 = "d047cc114023e12292533bb822b45c23cb51d310"
uuid = "fbd9d27c-2d1c-5c1c-99f2-7497d746985d"
version = "1.0.0"

[[deps.OrderedCollections]]
git-tree-sha1 = "cc4054e898b852042d7b503313f7ad03de99c3dd"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.8.0"

[[deps.PNGFiles]]
deps = ["Base64", "CEnum", "ImageCore", "IndirectArrays", "OffsetArrays", "libpng_jll"]
git-tree-sha1 = "67186a2bc9a90f9f85ff3cc8277868961fb57cbd"
uuid = "f57f5aa1-a3ce-4bc8-8ab9-96f992907883"
version = "0.4.3"

[[deps.PaddedViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "0fac6313486baae819364c52b4f483450a9d793f"
uuid = "5432bcbf-9aad-5242-b902-cca2824c8663"
version = "0.5.12"

[[deps.Parameters]]
deps = ["OrderedCollections", "UnPack"]
git-tree-sha1 = "34c0e9ad262e5f7fc75b10a9952ca7692cfc5fbe"
uuid = "d96e819e-fc66-5662-9728-84c9c7592b0a"
version = "0.12.3"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "8489905bcdbcfac64d1daa51ca07c0d8f0283821"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.8.1"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "Random", "SHA", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.11.0"
weakdeps = ["REPL"]

    [deps.Pkg.extensions]
    REPLExt = "REPL"

[[deps.PkgVersion]]
deps = ["Pkg"]
git-tree-sha1 = "f9501cc0430a26bc3d156ae1b5b0c1b47af4d6da"
uuid = "eebad327-c553-4316-9ea0-9fa01ccd7688"
version = "0.3.3"

[[deps.PlotUtils]]
deps = ["ColorSchemes", "Colors", "Dates", "PrecompileTools", "Printf", "Random", "Reexport", "StableRNGs", "Statistics"]
git-tree-sha1 = "3ca9a356cd2e113c420f2c13bea19f8d3fb1cb18"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.4.3"

[[deps.PlotlyBase]]
deps = ["ColorSchemes", "Dates", "DelimitedFiles", "DocStringExtensions", "JSON", "LaTeXStrings", "Logging", "Parameters", "Pkg", "REPL", "Requires", "Statistics", "UUIDs"]
git-tree-sha1 = "56baf69781fc5e61607c3e46227ab17f7040ffa2"
uuid = "a03496cd-edff-5a9b-9e67-9cda94a718b5"
version = "0.8.19"

[[deps.PlutoPlotly]]
deps = ["AbstractPlutoDingetjes", "Artifacts", "ColorSchemes", "Colors", "Dates", "Downloads", "HypertextLiteral", "InteractiveUtils", "LaTeXStrings", "Markdown", "Pkg", "PlotlyBase", "PrecompileTools", "Reexport", "ScopedValues", "Scratch", "TOML"]
git-tree-sha1 = "9ebe25fc4703d4112cc418834d5e4c9a4b29087d"
uuid = "8e989ff0-3d88-8e9f-f020-2b208a939ff0"
version = "0.6.2"

    [deps.PlutoPlotly.extensions]
    PlotlyKaleidoExt = "PlotlyKaleido"
    UnitfulExt = "Unitful"

    [deps.PlutoPlotly.weakdeps]
    PlotlyKaleido = "f2990250-8cf9-495f-b13a-cce12b45703c"
    Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "7e71a55b87222942f0f9337be62e26b1f103d3e4"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.61"

[[deps.PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "36d8b4b899628fb92c2749eb488d884a926614d3"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.3"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "5aa36f7049a63a1528fe8f7c3f2113413ffd4e1f"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.2.1"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "9306f6085165d270f7e3db02af26a400d580f5c6"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.4.3"

[[deps.PrettyTables]]
deps = ["Crayons", "LaTeXStrings", "Markdown", "PrecompileTools", "Printf", "Reexport", "StringManipulation", "Tables"]
git-tree-sha1 = "1101cd475833706e4d0e7b122218257178f48f34"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "2.4.0"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"
version = "1.11.0"

[[deps.ProgressMeter]]
deps = ["Distributed", "Printf"]
git-tree-sha1 = "8f6bc219586aef8baf0ff9a5fe16ee9c70cb65e4"
uuid = "92933f4c-e287-5a05-a399-4b506db050ca"
version = "1.10.2"

[[deps.QOI]]
deps = ["ColorTypes", "FileIO", "FixedPointNumbers"]
git-tree-sha1 = "8b3fc30bc0390abdce15f8822c889f669baed73d"
uuid = "4b34888f-f399-49d4-9bb3-47ed5cae4e65"
version = "1.0.1"

[[deps.Quaternions]]
deps = ["LinearAlgebra", "Random", "RealDot"]
git-tree-sha1 = "994cc27cdacca10e68feb291673ec3a76aa2fae9"
uuid = "94ee1d12-ae83-5a48-8b1c-48b8ff168ae0"
version = "0.7.6"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "StyledStrings", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"
version = "1.11.0"

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
version = "1.11.0"

[[deps.RangeArrays]]
git-tree-sha1 = "b9039e93773ddcfc828f12aadf7115b4b4d225f5"
uuid = "b3c3ace0-ae52-54e7-9d0b-2c1406fd6b9d"
version = "0.3.2"

[[deps.Ratios]]
deps = ["Requires"]
git-tree-sha1 = "1342a47bf3260ee108163042310d26f2be5ec90b"
uuid = "c84ed2f1-dad5-54f0-aa8e-dbefe2724439"
version = "0.4.5"
weakdeps = ["FixedPointNumbers"]

    [deps.Ratios.extensions]
    RatiosFixedPointNumbersExt = "FixedPointNumbers"

[[deps.RealDot]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "9f0a1b71baaf7650f4fa8a1d168c7fb6ee41f0c9"
uuid = "c1ae055f-0cd5-4b69-90a6-9a35b1a98df9"
version = "0.1.0"

[[deps.RecipesBase]]
deps = ["PrecompileTools"]
git-tree-sha1 = "5c3d09cc4f31f5fc6af001c250bf1278733100ff"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.3.4"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.RemoteFiles]]
deps = ["Dates", "FileIO", "HTTP"]
git-tree-sha1 = "9a0241c411af313068188e89ebf322cb49eedf52"
uuid = "cbe49d4c-5af1-5b60-bb70-0a60aa018e1b"
version = "0.5.0"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "838a3a4188e2ded87a4f9f184b4b0d78a1e91cb7"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.0"

[[deps.Rotations]]
deps = ["LinearAlgebra", "Quaternions", "Random", "StaticArrays"]
git-tree-sha1 = "5680a9276685d392c87407df00d57c9924d9f11e"
uuid = "6038ab10-8711-5258-84ad-4b1120ba62dc"
version = "1.7.1"
weakdeps = ["RecipesBase"]

    [deps.Rotations.extensions]
    RotationsRecipesBaseExt = "RecipesBase"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.SIMD]]
deps = ["PrecompileTools"]
git-tree-sha1 = "fea870727142270bdf7624ad675901a1ee3b4c87"
uuid = "fdea26ae-647d-5447-a871-4b548cad5224"
version = "3.7.1"

[[deps.SPICE]]
deps = ["CSPICE_jll", "LinearAlgebra"]
git-tree-sha1 = "505455711ac4c9d6b190e433bac95e48c0a38329"
uuid = "5bab7191-041a-5c2e-a744-024b9c3a5062"
version = "0.2.3"

[[deps.SPICEApplications]]
deps = ["CSPICE_jll", "DocStringExtensions"]
git-tree-sha1 = "68ae3fe971253b1c990249c0f21c41594ad86635"
uuid = "e12e0822-0612-48d4-a4bb-92984dd6b6ec"
version = "0.3.1"

[[deps.SPICEBodies]]
deps = ["AstroTime", "Dates", "DocStringExtensions", "LinearAlgebra", "SPICE"]
git-tree-sha1 = "702bb38dfb3818199a812a086f91232746d25538"
uuid = "19f1efb6-7162-484a-b3a1-b52c391689d7"
version = "1.2.1"

[[deps.SPICEKernels]]
deps = ["Dates", "DocStringExtensions", "Downloads", "HTTP", "Scratch"]
git-tree-sha1 = "29dab48c454e61ff0cebec63a8038ac7d45b5d0f"
uuid = "8e9d28ce-e483-4ef7-bfd9-45b8fef6369c"
version = "2.2.1"

[[deps.ScopedValues]]
deps = ["HashArrayMappedTries", "Logging"]
git-tree-sha1 = "1147f140b4c8ddab224c94efa9569fc23d63ab44"
uuid = "7e506255-f358-4e82-b7e4-beb19740aa63"
version = "1.3.0"

[[deps.Scratch]]
deps = ["Dates"]
git-tree-sha1 = "3bac05bc7e74a75fd9cba4295cde4045d9fe2386"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.2.1"

[[deps.SentinelArrays]]
deps = ["Dates", "Random"]
git-tree-sha1 = "712fb0231ee6f9120e005ccd56297abbc053e7e0"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.4.8"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"
version = "1.11.0"

[[deps.SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"
version = "1.11.0"

[[deps.SimpleBufferStream]]
git-tree-sha1 = "f305871d2f381d21527c770d4788c06c097c9bc1"
uuid = "777ac1f9-54b0-4bf8-805c-2214025038e7"
version = "1.2.0"

[[deps.SimpleTraits]]
deps = ["InteractiveUtils", "MacroTools"]
git-tree-sha1 = "5d7e3f4e11935503d3ecaf7186eac40602e7d231"
uuid = "699a6c99-e7fa-54fc-8d76-47d257e15c1d"
version = "0.9.4"

[[deps.Sixel]]
deps = ["Dates", "FileIO", "ImageCore", "IndirectArrays", "OffsetArrays", "REPL", "libsixel_jll"]
git-tree-sha1 = "2da10356e31327c7096832eb9cd86307a50b1eb6"
uuid = "45858cf5-a6b0-47a3-bbea-62219f50df47"
version = "0.1.3"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"
version = "1.11.0"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "66e0a8e672a0bdfca2c3f5937efb8538b9ddc085"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.2.1"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
version = "1.11.0"

[[deps.StableRNGs]]
deps = ["Random"]
git-tree-sha1 = "83e6cce8324d49dfaf9ef059227f91ed4441a8e5"
uuid = "860ef19b-820b-49d6-a774-d7a799459cd3"
version = "1.0.2"

[[deps.StackViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "46e589465204cd0c08b4bd97385e4fa79a0c770c"
uuid = "cae243ae-269e-4f55-b966-ac2d0dc13c15"
version = "0.1.1"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "PrecompileTools", "Random", "StaticArraysCore"]
git-tree-sha1 = "02c8bd479d26dbeff8a7eb1d77edfc10dacabc01"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.9.11"
weakdeps = ["ChainRulesCore", "Statistics"]

    [deps.StaticArrays.extensions]
    StaticArraysChainRulesCoreExt = "ChainRulesCore"
    StaticArraysStatisticsExt = "Statistics"

[[deps.StaticArraysCore]]
git-tree-sha1 = "192954ef1208c7019899fbf8049e717f92959682"
uuid = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
version = "1.4.3"

[[deps.Statistics]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "ae3bb1eb3bba077cd276bc5cfc337cc65c3075c0"
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.11.1"
weakdeps = ["SparseArrays"]

    [deps.Statistics.extensions]
    SparseArraysExt = ["SparseArrays"]

[[deps.StringManipulation]]
deps = ["PrecompileTools"]
git-tree-sha1 = "725421ae8e530ec29bcbdddbe91ff8053421d023"
uuid = "892a3eda-7b42-436c-8928-eab12a02cf0e"
version = "0.4.1"

[[deps.StyledStrings]]
uuid = "f489334b-da3d-4c2e-b8f0-e476e12c162b"
version = "1.11.0"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "7.7.0+0"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.TableMetadataTools]]
deps = ["DataAPI", "Dates", "TOML", "Tables", "Unitful"]
git-tree-sha1 = "c0405d3f8189bb9a9755e429c6ea2138fca7e31f"
uuid = "9ce81f87-eacc-4366-bf80-b621a3098ee2"
version = "0.1.0"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "OrderedCollections", "TableTraits"]
git-tree-sha1 = "598cd7c1f68d1e205689b1c2fe65a9f85846f297"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.12.0"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.TensorCore]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1feb45f88d133a655e001435632f019a9a1bcdb6"
uuid = "62fd8b95-f654-4bbd-a8a5-9c27f68ccd50"
version = "0.1.1"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
version = "1.11.0"

[[deps.TestItems]]
git-tree-sha1 = "42fd9023fef18b9b78c8343a4e2f3813ffbcefcb"
uuid = "1c621080-faea-4a02-84b6-bbd5e436b8fe"
version = "1.0.0"

[[deps.TiffImages]]
deps = ["ColorTypes", "DataStructures", "DocStringExtensions", "FileIO", "FixedPointNumbers", "IndirectArrays", "Inflate", "Mmap", "OffsetArrays", "PkgVersion", "ProgressMeter", "SIMD", "UUIDs"]
git-tree-sha1 = "f21231b166166bebc73b99cea236071eb047525b"
uuid = "731e570b-9d59-4bfa-96dc-6df516fadf69"
version = "0.11.3"

[[deps.TranscodingStreams]]
git-tree-sha1 = "0c45878dcfdcfa8480052b6ab162cdd138781742"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.11.3"

[[deps.Tricks]]
git-tree-sha1 = "6cae795a5a9313bbb4f60683f7263318fc7d1505"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.10"

[[deps.URIs]]
git-tree-sha1 = "67db6cc7b3821e19ebe75791a9dd19c9b1188f2b"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.5.1"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"
version = "1.11.0"

[[deps.UnPack]]
git-tree-sha1 = "387c1f73762231e86e0c9c5443ce3b4a0a9a0c2b"
uuid = "3a884ed6-31ef-47d7-9d2a-63182c4928ed"
version = "1.0.2"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"
version = "1.11.0"

[[deps.Unitful]]
deps = ["Dates", "LinearAlgebra", "Random"]
git-tree-sha1 = "c0667a8e676c53d390a09dc6870b3d8d6650e2bf"
uuid = "1986cc42-f94f-5a68-af5c-568840ba703d"
version = "1.22.0"

    [deps.Unitful.extensions]
    ConstructionBaseUnitfulExt = "ConstructionBase"
    InverseFunctionsUnitfulExt = "InverseFunctions"

    [deps.Unitful.weakdeps]
    ConstructionBase = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"

[[deps.WCS]]
deps = ["ConstructionBase", "WCS_jll"]
git-tree-sha1 = "858cf2784ff27d908df7a3fe22fcd5fbf02f508b"
uuid = "15f3aee2-9e10-537f-b834-a6fb8bdb944d"
version = "0.6.2"

[[deps.WCS_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "947bfa11fcd65dac9e9b2e963504fba6b4971d31"
uuid = "550c8279-ae0e-5d1b-948f-937f2608a23e"
version = "7.7.0+0"

[[deps.WeakRefStrings]]
deps = ["DataAPI", "InlineStrings", "Parsers"]
git-tree-sha1 = "b1be2855ed9ed8eac54e5caff2afcdb442d52c23"
uuid = "ea10d353-3f73-51f8-a26c-33c1cb351aa5"
version = "1.4.2"

[[deps.WebP]]
deps = ["CEnum", "ColorTypes", "FileIO", "FixedPointNumbers", "ImageCore", "libwebp_jll"]
git-tree-sha1 = "aa1ca3c47f119fbdae8770c29820e5e6119b83f2"
uuid = "e3aaa7dc-3e4b-44e0-be63-ffb868ccd7c1"
version = "0.1.3"

[[deps.WoodburyMatrices]]
deps = ["LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "c1a7aa6219628fcd757dede0ca95e245c5cd9511"
uuid = "efce3f68-66dc-5838-9240-27a6d6f5f9b6"
version = "1.0.0"

[[deps.WorkerUtilities]]
git-tree-sha1 = "cd1659ba0d57b71a464a29e64dbc67cfe83d54e7"
uuid = "76eceee3-57b5-4d4a-8e66-0e911cebbf60"
version = "1.6.1"

[[deps.XML2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libiconv_jll", "Zlib_jll"]
git-tree-sha1 = "a2fccc6559132927d4c5dc183e3e01048c6dcbd6"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.13.5+0"

[[deps.XSLT_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgcrypt_jll", "Libgpg_error_jll", "Libiconv_jll", "XML2_jll", "Zlib_jll"]
git-tree-sha1 = "7d1671acbe47ac88e981868a078bd6b4e27c5191"
uuid = "aed1982a-8fda-507f-9586-7b0439959a61"
version = "1.1.42+0"

[[deps.XZ_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "56c6604ec8b2d82cc4cfe01aa03b00426aac7e1f"
uuid = "ffd25f8a-64ca-5728-b0f7-c24cf3aae800"
version = "5.6.4+1"

[[deps.Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "9dafcee1d24c4f024e7edc92603cedba72118283"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.8.6+3"

[[deps.Xorg_libXau_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "e9216fdcd8514b7072b43653874fd688e4c6c003"
uuid = "0c0b7dd1-d40b-584c-a123-a41640f87eec"
version = "1.0.12+0"

[[deps.Xorg_libXdmcp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "89799ae67c17caa5b3b5a19b8469eeee474377db"
uuid = "a3789734-cfe1-5b06-b2d0-1dd0d9d62d05"
version = "1.1.5+0"

[[deps.Xorg_libXext_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll"]
git-tree-sha1 = "d7155fea91a4123ef59f42c4afb5ab3b4ca95058"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.6+3"

[[deps.Xorg_libpthread_stubs_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "c57201109a9e4c0585b208bb408bc41d205ac4e9"
uuid = "14d82f49-176c-5ed1-bb49-ad3f5cbd8c74"
version = "0.1.2+0"

[[deps.Xorg_libxcb_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "XSLT_jll", "Xorg_libXau_jll", "Xorg_libXdmcp_jll", "Xorg_libpthread_stubs_jll"]
git-tree-sha1 = "1a74296303b6524a0472a8cb12d3d87a78eb3612"
uuid = "c7cfdc94-dc32-55de-ac96-5a1b8d977c5b"
version = "1.17.0+3"

[[deps.Xorg_xtrans_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "6dba04dbfb72ae3ebe5418ba33d087ba8aa8cb00"
uuid = "c5fb5394-a638-5e4d-96e5-b29de1b5cf10"
version = "1.5.1+0"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+1"

[[deps.Zstd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "622cf78670d067c738667aaa96c553430b65e269"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.7+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.11.0+0"

[[deps.libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "055a96774f383318750a1a5e10fd4151f04c29c5"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.46+0"

[[deps.libsixel_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "Libdl", "libpng_jll"]
git-tree-sha1 = "c1733e347283df07689d71d61e14be986e49e47a"
uuid = "075b6546-f08a-558a-be8f-8157d0f608a5"
version = "1.10.5+0"

[[deps.libwebp_jll]]
deps = ["Artifacts", "Giflib_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libglvnd_jll", "Libtiff_jll", "libpng_jll"]
git-tree-sha1 = "d2408cac540942921e7bd77272c32e58c33d8a77"
uuid = "c5f90fcd-3b7e-5836-afba-fc50a0988cb2"
version = "1.5.0+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.59.0+0"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+2"
"""

# ╔═╡ Cell order:
# ╟─75d03ef4-d8b2-11ef-076a-058846f3b6ba
# ╟─4cc6fb84-cefe-4571-850c-762643ff4ffc
# ╟─7d10737f-1691-43e5-891f-118e41cd771a
# ╟─65d2286a-2786-4f96-8193-d0c4fe77d57a
# ╠═d12e83b5-8351-44ef-aa4c-b5ace3b4eb39
# ╟─b4119602-990d-47b0-8ea5-7f14e17d9e9f
# ╠═94cccd09-ccb9-48d2-b533-246ac0acd405
# ╠═5523bfd6-4d1c-472f-a028-266b9a891df8
# ╟─f4d52a6a-644e-4ff1-861f-a0531c596040
# ╟─9477e1ef-92e7-49fe-9319-e894ef45852a
# ╟─10c77d40-dcb9-4620-b9c1-a47a56621a0c
# ╟─738ef43b-0433-405a-9a63-9074edbfeb14
# ╠═21afa6af-1df0-4c47-b106-1b9d1e161aa7
# ╟─8bbccbde-4850-4f9d-941a-b163e2133afc
# ╠═2bbcab7e-ee23-4136-b686-5472e61cd117
# ╟─51186ae1-baac-4868-950f-1c9a86d720d8
# ╟─867445e3-e2f7-4cca-bf70-26dfcae825dd
# ╠═6fc4ec56-0591-4f61-bdce-43ef796ab3a5
# ╠═cf81d974-2bf7-4da0-a781-3519953554ff
# ╟─6193211b-8ec0-4f88-87df-35247c01353a
# ╟─568347fb-92a3-4435-8204-80a1a0a1eaef
# ╟─68faa552-2651-4349-9a54-8c9f82e86158
# ╟─a3a65c1c-a44e-475e-8044-35c453709483
# ╠═a9960706-4f5b-41e9-8dd4-2fbf24f4daec
# ╟─4ed0072f-6159-4893-b21b-e035e51a6689
# ╟─5a0b3e26-7271-4b08-aa67-68c3af1421c0
# ╟─49b6c887-17fb-45f0-9dff-3aff12e03be5
# ╟─983a1c03-0344-4905-8cf2-b799003eb94c
# ╟─38d3228b-abf6-435f-b287-ef5b40464bfa
# ╟─13e464bb-30d2-4e6e-b038-69871acbba65
# ╠═376cb78b-765a-4d8a-aaef-884ec579a2b5
# ╟─cd32b1d0-f455-4822-ad19-6560044d6c4a
# ╟─2f9fed6d-0fb0-4a1e-afad-6d7beda95ba1
# ╟─8e0e738d-6bdf-4992-bc0e-ea00ea9617ba
# ╟─3e475b77-638c-4bb2-81c6-d7146b72c41f
# ╠═84c11014-8890-4348-96b6-8e701e458de4
# ╟─117751ce-7c9e-461f-9ef9-6310ff0ecfac
# ╟─43a16d76-7de9-4f19-b1e4-a03457fd1e11
# ╠═527c1ad3-02d1-4ea5-98b2-d0054f6b5a91
# ╟─aabbcb9d-4310-437f-b7da-03b385916400
# ╟─fdd7bfe6-d4f7-434e-bac3-dc8994a17a6e
# ╟─64cf11a7-09ef-459a-98b5-3e5f8a8cd1b5
# ╟─864d23ed-d44e-4d3b-887c-73e49a909071
# ╠═6bed5463-00a8-4c73-b0dc-6c7397c7a099
# ╠═53e5fca6-41ee-4a46-9a41-d9f4e0673c8e
# ╟─df00e717-2574-4281-9838-1f446960731a
# ╠═50f77772-c419-4ad7-b9d6-12554302a518
# ╠═8479dc29-366f-43b2-bfed-2c2b38dd72f8
# ╟─2c5f91b7-4baf-4bbe-8634-c69223916e8f
# ╟─0043f0a6-d309-4527-a554-d37c73c36dfa
# ╟─dd382487-c181-4aad-b9c5-2e9bc422ed01
# ╟─7db58c7e-4642-4295-80ae-ef3fd968bf9d
# ╠═1f68afec-5916-4fcf-905a-f83a42bdf09b
# ╠═53512b8f-3120-4f9a-bb5f-ff8aefc96408
# ╠═7869c86f-52c3-4b3b-be59-b4f7626faf12
# ╟─9159cb78-6d0e-4c12-8f42-6b8e8316d167
# ╟─e99ae23f-c998-4e09-8d24-5df55b4385ee
# ╠═a23c40dc-0af3-4c3a-8172-203f58603bbb
# ╠═05b2f9fe-61d2-4640-bbae-78d6d7465597
# ╠═db72ee5e-070b-4dff-b3b6-8b9915ed7b3e
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
