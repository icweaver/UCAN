### A Pluto.jl notebook ###
# v0.20.13

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

# ╔═╡ 635efbd3-bed2-4236-9eb2-c816a713990b
using Statistics

# ╔═╡ 6bc5d30d-2051-4249-9f2a-c4354aa49198
begin
	# Notebook UI
	using PlutoUI, CommonMark
	
	# Data wrangling
	using CCDReduction, DataDeps, DataFramesMeta

	# Web
	using HTTP, JSONTables, TableScraper
	
	# Visualization and analysis
	using AstroImages, PlutoPlotly, AstroAngles, Photometry, ImageCore
	using AstroImages: restrict
	using Dates, Unitful 

	AstroImages.set_cmap!(:cividis)

	# Python
	using PythonCall, CondaPkg
	CondaPkg.add_pip("astroalign")
	CondaPkg.add("numpy"; version="<2")

	# Use DataDeps.jl for dataset management
	# Auto-download data to current directory by default
	ENV["DATADEPS_ALWAYS_ACCEPT"] = "true"
	ENV["DATADEPS_LOAD_PATH"] = @__DIR__
	DataDep(
		"data",
		"""
		UCAN Data Files
		Website: https://www.seti.org/education/ucan/unistellar-education-materials/
		""",
		["https://www.dropbox.com/scl/fo/uxuluatuh82yy9i9nsixs/ALn9NbC5M4aJEPIAsnZU12M?rlkey=vpbb4tvlt59dtvvssqlpc5v1x&st=x9fbkhlj&dl=1"],
		["1ee0a7459a5a4e5fcec433a7bfbdcdfaf04844a7b081dcb181ecf5355a38eb25"],
		post_fetch_method = unpack,
	) |> register
end

# ╔═╡ 3d8a4c43-1a17-4a36-84e8-47a98493ca99
md"""
# ⚪ ⚫ Unistellar Eclipsing Binary Lab

In this lab we will observe an eclipsing binary in real time and explore how to produce a light curve for it.

Having some familiarity in high-level programming languages like Julia or Python will be useful, but not necessary, for following along with the topics covered. At the end of this notebook, you will hopefully have the tools to build your own analysis pipelines for processing astronomical photometry, as well as understand the principles behind other astronomical software at a broad level.
"""

# ╔═╡ f0678404-72db-4bfd-9a44-ef0b66f3a64f
md"""
With this requisite information out of the way, let's get started!
"""

# ╔═╡ 49e1559e-bb19-4e8e-a9a9-67cb2c2d6931
msg_adding_colors = md"""
##### Adding colors in Julia 🎨
This makes magenta!

```julia
using ImageCore

RGB(1, 0, 0) + RGB(0, 0, 1)
```

$(RGB(1, 0, 0) + RGB(0, 0, 1))
""";

# ╔═╡ 84d9ed94-11cb-4272-8bd3-d420c50f990d
msg(x; title="Details") = details(title, x);

# ╔═╡ 14e0627f-ada1-4689-9bc6-c877b81aa582
cm"""
!!! note "Using this notebook"
	Some parts of this [Pluto notebook](https://plutojl.org/) are partially interactive online, but for full interactive control, it is recommended to download and run this notebook locally. For instructions on how to do this, click the `Edit or run this notebook` button in the top right corner of the page, or [click on this direct link](https://computationalthinking.mit.edu/Fall23/installation/) which includes a video and written instructions for getting started with Julia and Pluto 🌱.

	!!! tip "Coffee break? ☕"
		**Note**: This notebook will download all of the analysis packages and data needed for us, so the first time it runs may take a little while (~ a few minutes depending on your internet connection and platform). Clicking on the `Status` tab in the bottom right will bring up a progress window that we can use to monitor this process, and it also includes an option at the bottom marked `Notify when done` that can be selected to give us a notification pop-up in our browser when everything is finished.

	This is a fully hackable notebook, so exploring the [source code](https://github.com/icweaver/UCAN/blob/main/EBs/EB_lab.jl) and making your own modifications is encouraged! Unlike Jupyter notebooks, Pluto notebook are just plain Julia files. Any changes you make in the notebook are automatically saved to the source file.

	!!! tip "Advanced: bring your own editor"
		This works in the opposite direction too; any changes you make to the source file, say in your favorite editor, will automatically be reflected in the notebook in your browser! To enable this feature, just add this keyword to the function that was used to start Pluto:

		```julia-repl
		julia> using Pluto
		
		julia> Pluto.run(auto_reload_from_file=true)
		
		# This will be on by default in an upcoming release =]
		```

		The location of the file for this notebook is displayed in the bar at the very top of this page, and can also be modified there if you want to change where this notebook lives.

	Periodically throughout the notebook we will include collapsible sections like the one below to provide additional information about items outside the scope of this lab that may be of interest (e.g., plotting, working with javascript, creating widgets).

	$(msg(msg_adding_colors))

	In the local version of this notebook, an "eye" icon will appear at the top left of each cell on hover to reveal the underlying code behind it and a `Live Docs` button will also be available in the bottom right of the page to pull up documentation for any function that is currently selected. In both local and online versions of this notebook, user defined functions and variables are also underlined, and (ctrl) clicking on them will jump to where they are defined. For more examples of using these notebooks for Unistellar science, check out our recent [Spectroscopy Lab](https://icweaver.github.io/UCAN/spectroscopy/notebook.html)!
"""

# ╔═╡ aa005b55-626e-41e0-8fe1-137bd7dd5599
md"""
## Background 📖

It turns out that the alien world described in the [3 Body Problem](https://www.netflix.com/tudum/articles/3-body-problem-teaser-release-date) is not too far off from what we see in reality. Star systems can be made up of just one star like in our system, three as in the tv show and book series from which the 3 Body Problem [draws its inspiration](https://en.wikipedia.org/wiki/Alpha_Centauri), or even as many as six different stars as in this [recently discovered system](https://science.nasa.gov/universe/exoplanets/discovery-alert-first-six-star-system-where-all-six-stars-undergo-eclipses/)! While these would make for some quite interesting sunsets, a system's stability decreases as more bodies are added. This is partly why the most common star systems we see are singular star systems, followed closely behind by binary systems, which have two stars and account for [nearly two-thirds of all star systems in the Milky Way](https://pweb.cfa.harvard.edu/news/most-milky-way-stars-are-single).

A sub-class of this binary star case, known as eclipsing binaries, has proved to be an invaluable tool for helping us learn more about [orbital mechanics and stellar evolution](https://www.aavso.org/introduction-why-are-eclipsing-binary-stars-important). In these types of systems, not only do these two stars orbit about their common center-of-mass, but they do so along our line of sight. In other words, eclipsing binaries are star systems where each star passes in front of the other from our vantage point. As they do so, the combined light that we receive from both objects will vary in time.
"""

# ╔═╡ 4266575e-e19f-48e4-8b21-6f296c6d3f33
md"""
$(Resource("https://upload.wikimedia.org/wikipedia/commons/transcoded/7/7e/Artist%E2%80%99s_impression_of_eclipsing_binary.ogv/Artist%E2%80%99s_impression_of_eclipsing_binary.ogv.720p.vp9.webm"))

*ESO/L. Calçada*

In this visualization, we see how the observed brightness of an eclipsing binary system changes based on how much of each star is visible at a given point in time from our perspective. When they are both unobstructed the measured brightness is maximum, and when one is partially covered by the other, the combined brightness decreases periodically over time. In this lab, we will capture this dance going on in real time in a fairly popular constellation.
"""

# ╔═╡ aaaaa4d6-737b-4e53-a3a4-fcac09789d4e
md"""
## Introduction 🤝

[W Ursae Majoris (W UMa)](https://www.aavso.org/vsots_wuma) is an eclipsing binary system located in the [Ursa Major](https://en.wikipedia.org/wiki/Ursa_Major) constellation, and can be seen being chased across the sky by the Big Dipper throughout the night:

$(Resource("https://github.com/icweaver/UCAN/blob/main/EBs/data/constellation_WUMa.png?raw=true"))

*W UMa is marked by the larger, red dot to the right of the Big Dipper*
"""

# ╔═╡ c1bbb6a2-6996-4fee-a642-a0212b473474
md"""
Discovered in the early 1900s, this system is composed of two main-sequence F-type stars orbiting so closely together that they are expected to be [contact binaries](https://en.wikipedia.org/wiki/Contact_binary), meaning they share a common gaseous envelope. Their proximity to each other also gives this system an astonishingly short orbital period of just over 8 hours. Because of how neatly this fits into an Earth day, eclipse events occur at almost the same time every night, making them the ideal target for regular follow-up study. When the fainter of the two passes in front of the brighter one, we call that a _primary eclipse_, and when the brighter companion passes in front of the fainter one, we call it a _secondary eclipse_.

According to the [AAVSO ephemeris](https://www.aavso.org/sites/default/files/AAVSO_%20EB_Ephemeris_%202024.pdf) for this system, primary and secondary eclipsed are predicted to occur around **3:00 and 7:00 UTC**, respectively. Due to the similar sizes and spectral types of each star, the eclipse depths for both are fairly similar and can vary by almost a whole apparent magnitude! With a total duration of about three hours, the entire light curve for a given eclipse can be captured in a single night.

!!! tip
	For more on reading eclipsing binary ephemerides, please see this [AAVSO resource](https://www.aavso.org/how-use-eb-ephemeris).
"""

# ╔═╡ abb9a9c8-5cac-4af3-b0a0-b7a3608dfe1a
md"""
## Data inspection 🔎

For this lab, we will be using eVscope 2 data collected for this target on the night of March 25th, 2024. Observations were taken in the [exoplanet science mode](https://science.unistellar.com/exoplanets/tutorial/) with the following observation parameters:

```
Observing mode: Exoplanets
Eclipse mid-point: 23:00 PT
Eclipse duration: 3 hrs
Ra: 09h 43m 45.47s
Dec: +55° 57' 09.07"   
Duration: 3 hrs
Exposure time (ms): 1400
Cadence (ms): 4000
Recommended Gain (dB): 0
Max Gain (dB): 1.78
```


!!! note
	The sample data for this lab can be downloaded [here](https://drive.google.com/drive/folders/1P7PTtx9LUnR-QF_SWjszTBjCwpJHZ7AN?usp=sharing).
"""

# ╔═╡ b360ad74-58b7-47b5-a8b0-437ef1119303
md"""
Let's use [`fitscollection`](https://juliaastro.org/CCDReduction.jl/stable/api/#CCDReduction.fitscollection-Tuple{String}) from [CCDReductions.jl](https://github.com/JuliaAstro/CCDReduction.jl?tab=readme-ov-file) to take a quick glance at the fits files in this folder:

!!! note

	Much like an Excel spreadsheet, dependent cells are aware of each other, so package imports can be placed anywhere in the notebook. For organizational purposes, we have placed all package imports (like CCDReductions.jl) at the bottom of this notebook.
"""

# ╔═╡ 7c078085-ff30-400d-a0ab-2680f468c415
const DATA_DIR = datadep"data";

# ╔═╡ 1356c02f-9ff2-491f-b55d-666ee76e6fae
df_sci = let
	df = fitscollection(DATA_DIR; abspath=false)
	@transform! df :"DATE-OBS" = DateTime.(:"DATE-OBS")
end;

# ╔═╡ 06d26240-81b6-401b-8eda-eab3a9a0fb20
md"""
We see that we have $(nrow(df_sci)) fits files taken over the following period in UTC:
"""

# ╔═╡ 335a1a12-379a-4e0d-a3de-788369ae3818
df_sci[:, "DATE-OBS"] |> extrema

# ╔═╡ a04886d9-471a-40ec-9f0b-65ffe89932cf
md"""
and with the following header fields:
"""

# ╔═╡ 8a78029c-ddf5-4ada-b6d3-a9a649bdbae8
df_sci |> names |> print

# ╔═╡ cdf14fe8-6b27-44eb-b789-6cf072f4d184
msg(md"""
!!! note ""
	Also known as the [pipe operator](https://docs.julialang.org/en/v1/manual/functions/#Function-composition-and-piping), this is a convenient way to pass the output of one function as input to the next. For example,

	```julia
	sqrt(sum([1, 4, 5, 6])) # 4.0
	```

	is equivalent to:

	```julia
	[1, 4, 5, 6] |> sum |> sqrt # 4.0
	```
"""; title=md"What does `|>` do?")

# ╔═╡ a38466b5-c7fb-4600-904b-b7ddd7afd272
md"""
Let's use [AstroImages.jl](https://github.com/JuliaAstro/AstroImages.jl) to take a look at the image data for one of these files:
"""

# ╔═╡ 2b8c75f6-c148-4c70-be6a-c1a4b95d5849
img_sci = load(first(df_sci).path); # The semicolon hides automatic output

# ╔═╡ dbe812e2-a795-4caa-842d-07da5eabcade
reverse(img_sci)

# ╔═╡ 9d2b2434-7bd9-42c4-b986-34969101b285
md"""
and compare it to our corresponding [finder chart](https://astro.swarthmore.edu/transits/finding_charts.cgi) for our target:
"""

# ╔═╡ 74197e45-3b80-44ad-b940-f2544f2f9b54
Resource("https://github.com/icweaver/UCAN/blob/main/EBs/data/finder_WUMa.jpg?raw=true")

# ╔═╡ a6de852c-01e6-49a2-bc78-8d1b6eb51c0c
md"""
!!! note "Why did we reverse the image?"
	For easier comparison, we flipped our science frame image over the vertical axis so that it would be in the same orientation as our finder chart.

We have a match! Here is the associated header information for our science frame:
"""

# ╔═╡ 7d7cd508-be27-4f52-bc13-91c702450167
header(img_sci)

# ╔═╡ f6197e8e-3132-4ab5-86d7-32572e337c58
img_size, img_eltype = size(img_sci), eltype(img_sci)

# ╔═╡ 5abbcbe0-3ee6-4658-9c99-e4567a23e3f6
md"""
It looks like this image is $(first(img_size)) x $(last(img_size)) pixels, with the ADU counts for each pixel stored as a $(img_eltype) to reduce memory storage. Now that we know that we are pointing at the right place in the sky, let's take a look at the quality of our images.
"""

# ╔═╡ b7d3fb2b-c113-413c-b340-9dfb0a9b78af
md"""
### A note on image calibration

A critical step in analyzing astronomical data is accounting for sources of noise that may impact our final image. This process is known as calibration, and its purpose is to increase the signal-to-noise ratio of our science images. Here is a nice summary modified from [Practical Astrophotography](https://practicalastrophotography.com/a-brief-guide-to-calibration-frames/) of three of the main sources of noise that we typically try to calibrate for:

!!! note ""
	**Bias frames:** "Your camera inherently has a base level of read-out noise as it reads the values of each pixel of the sensor, called bias. When averaged out, basically it’s an inherent gradient to the sensor. Bias Frames are meant to capture this so it can be removed."

	**Dark frames:** "When taking a long exposure, the chip will introduce "thermal" noise. Its level is magnified by three things – temperature, exposure time, and ISO. Dark frames are used to subtract this sensor noise from your image and mitigate "hot or cold" pixels. (Some modern sensors automatically calculate dark levels and don't need dark frames). Dark Frames also will calibrate the chip so all pixels give the same value when not exposed to light."

	**Flat frames:** "I've seen people say flats help with light pollution. NOT TRUE AT ALL. Flat frames allow you to calculate the correction factor for each pixel so they all give the same value when exposed to the same quantity of light for a given optical path. Things like dust motes, lens vignetting consistently reduce the light to a given pixel, flat frames allow you to mathematically remove them to give a smooth evenly illuminated image."
"""

# ╔═╡ 2b32512b-63df-4a48-8e72-bf20aa75a845
md"""
Different flat fielding techniques are being examined by our team, but in general this has not been oberserved to be a significant source of noise in science mode observations. In practice, the [sensor calibration](https://help.unistellar.com/hc/en-us/articles/360011333600-Sensor-calibration-Dark-Frame-How-and-Why) step that is required at the end of science observations are set to the same gain and exposure time as your science images. By doing this, the bias frame is automatically built into the dark frames collected during this step, so no separate bias acquisition is needed.

We find that the contribution from dark noise does not impact our observations significantly, so we have excluded this calibration step for simplicity. Stay tuned for a future calibration notebook though where we will explore these procedures in more detail!
"""

# ╔═╡ 035fcecb-f998-4644-9650-6aeaced3e41f
imgs_sci = [load(f.path) for f in eachrow(df_sci)];

# ╔═╡ a1cb55ef-a33c-4506-bea4-aa6124026b75
md"""
We turn now (pun not intended) to the matter of field rotation.
"""

# ╔═╡ 6773c197-941e-4de0-b017-ec036fb851bb
md"""
### Field rotation

Before defining this phenomenon, let's first see it in action. Drag the slider below to scroll through each of our science frames. (Note for the rest of this notebook that we will be using the default image orientation in the plotting software):
"""

# ╔═╡ 5cc14d4f-d156-420c-a404-90c541217d83
md"""
!!! note "Apertures and comparison stars"

	To better show the frame to frame differences, we also added some sample target and comparison star aperturess (in green and orange, respectively) centered on the first frame in our image series. We use comparison stars to divide out common systematics like atmospheric turbulence and other changes in seeing conditions so that ideally only the target signal will be left.
"""

# ╔═╡ 916b8558-b49c-40b6-b9d3-9915d4fe75f0
ap_radius = 24

# ╔═╡ f1ed6484-8f6a-4fbf-9a3d-0fe20360ab3b
# Aperture object that will be used for photometry
# (x_center, y_center, radius)
ap_target = CircularAperture(1029, 782, ap_radius);

# ╔═╡ 954c7918-7dd1-4967-a67b-7856f00dc498
ap_comp1 = CircularAperture(1409, 999, ap_radius);

# ╔═╡ 59fd63bd-5df1-4a45-8505-f2b8c740e488
ap_comp2 = CircularAperture(1153, 711, ap_radius);

# ╔═╡ c06e64ef-4085-4bb5-9b8b-2ed244d5dbe8
md"""
Frame number: $(frame_slider = @bind frame_i Slider(1:length(imgs_sci); show_value=true))
"""

# ╔═╡ 7d54fd96-b268-4964-929c-d62c7d89b4b2
md"""
Uh-oh, we see that our images are literally rotating out from under us! This [field rotation](https://calgary.rasc.ca/field_rotation.htm) and also some drift that needed to be manually corrected partway through the observation are normal effects of taking long duration observations on an alt-az mount. Fortunately, it is fairly manageable to handle this as we will see in the next section.
"""

# ╔═╡ 1df329a0-629a-4527-8e5d-1dbac9ed8497
md"""
## Image alignment 📐

A typical astronomical observation might use the know RA and Dec of the field to [plate solve](https://astrobackyard.com/plate-solving/) each frame against background sources (see, e.g., [astrometry.net](https://astrometry.net/)). This then gives a coordinate transformation (e.g., with the [World Coordinate System (WCS) standard](https://fits.gsfc.nasa.gov/fits_wcs.html)) that can be applied to each frame to align them to a common grid with open source tools like [AstroImageJ](https://www.astro.louisville.edu/software/astroimagej/). Unfortunately, plate solving is a computationally expensive process that can take quite a while, especially if we have a large number of frames. Fortunately, there is a nice alternative that we can use if we do not care about the WCS information: [asterisms](https://en.wikipedia.org/wiki/Asterism_(astronomy)).

In this process, one frame is aligned to another in much the same way that human brain might: by matching common shapes between each frame to each other. This works indpendently of WCS information, so it completely avoids the need to plate solve our images. We will employ the Python package [`astroalign`](https://astroalign.quatrope.org/en/latest/index.html) to perform this process.
"""

# ╔═╡ d6bba196-213e-4c90-8d8e-f2ffc8108da6
md"""
!!! tip "Future work"
	Stay tuned for an upcoming notebook where we will examine this asterism alignment process in more depth!
"""

# ╔═╡ e7ad4e24-5dc9-4713-836a-be001304e45c
md"""
Let's see how our aligned frames look below:
"""

# ╔═╡ 102ce649-e560-470e-afa5-699db577e148
md"""
Nice! The rotation looks to have been successfuly transformed out. We turn next to computing the photometry for our aligned series of frames.
"""

# ╔═╡ 3d77a38f-1e2f-40a7-bfec-90acf382f042
md"""
#### Python helper functions
"""

# ╔═╡ b944bc98-ff4b-4851-89ea-1ee4e3191759
@py begin
	import numpy as np
	import astroalign as aa
end

# ╔═╡ 36db58d8-23be-461a-ac75-998c8ad43068
# Workaround. Apparently just wrapping img in a numpy array fails somewhere
# maybe in the call to sep within astroalign
function to_py(img)
	arr = np.zeros_like(img)
	PyArray(arr; copy=false) .= img
	return arr
end

# ╔═╡ 03d38a82-4c31-4f3a-9afe-d1caead5e8af
# Align img2 onto img1
function align(img2, img1)
	registered_image, footprint = aa.register(
		to_py(img2),
		to_py(img1);
		min_area = 25,
		detection_sigma = 2,
	)
	return shareheader(img2, PyArray(registered_image))
end

# ╔═╡ bdc24b15-d14a-422c-a7aa-5335547fa53c
function align_frames(imgs)
	fixed = first(imgs)
	frames_aligned = map(imgs[begin+1:end]) do img
		align(img, fixed)
	end
	return [fixed, frames_aligned...]
end

# ╔═╡ 1fe59945-8bce-44f3-b548-9646c2ce6bda
imgs_sci_aligned = align_frames(imgs_sci);

# ╔═╡ 73e16c0e-873c-46a3-a0fd-d7ed5405ed7b
md"""
Frame number: $(frame_slider_aligned = @bind frame_i_aligned Slider(1:length(imgs_sci_aligned); show_value=true))
"""

# ╔═╡ d6d19588-9fa5-4b3e-987a-082345357fe7
md"""
## Aperture photometry 🔾

Now that we have some science frames to work with, the next step is to begin counting the flux coming from our target system so that we can measure it over time. We will use the [Photomtery.jl](https://github.com/JuliaAstro/Photometry.jl) package which is inspired by other tools like astropy's [`photutils`](https://github.com/astropy/photutils) and C's [`SEP`](https://github.com/kbarbary/sep) library to perform the photometry. 

!!! note
	More at <https://juliaastro.org/dev/modules/AstroImages/guide/photometry/>
"""

# ╔═╡ 381d0147-264b-46f6-82ab-8c840c50c7d1
aps = [ap_target, ap_comp1, ap_comp2]

# ╔═╡ 79c924a7-f915-483d-aee6-94e749d3b004
aperture_sums = map(imgs_sci_aligned) do img
	# Returns (x_center, y_center, aperture_sum)
	# for each aperture
	p = photometry(aps, img)
	
	# Just store the aperture sum for each frame
	p.aperture_sum
end;

# ╔═╡ 0d07e670-4ddb-41ce-ac2c-60991a52ded4
md"""
We now have a vector of aperture sums, one row per frame, one set of aperture sums per frame in the order of our aperture list `aps`. This lends itself naturally to a matrix where each row is a given frame, and each column is an aperture (target, comp1, etc.), so let's convert it to one and view it with its corresponding observation times in a DataFrame:
"""

# ╔═╡ 96dc5bbe-3284-43a0-8c04-c1bb51ad618b
df_phot = let
	# `stack` converts to a Matrix
	# `:auto` names the columns for us
	# `copycols` sets whether we want a view or copy of the source matrix 
	data = stack(aperture_sums; dims=1)
	data ./ median(data; dims=1)
	
	df = DataFrame(data, :auto; copycols=false)

	@transform! df begin
		:x1 = :x1 / median(:x1)
		:x2 = :x2 / median(:x2)
		:x3 = :x3 / median(:x3)
	end
	
	# Place the observation time in the first column
	insertcols!(df, 1, :t => df_sci.:"DATE-OBS")
end

# ╔═╡ 15ad7461-9c40-4755-8f00-14aa3be53e0f
md"""
By convention, `t` is our observation time, `x1` is for our target star, and `x2` and up are our comparison stars. We can now visualize the light curve of our target from our photometry table:
"""

# ╔═╡ 6470b357-4dc6-4b2b-9760-93d64bab13e9
let
	# Switch to long "tidy" format to use convenient plotting syntax
	p = plot(stack(df_phot);
		x = :t,
		y = :value,
		color = :variable,
		mode = :markers,
	)

	layout = Layout(
		xaxis = attr(title="Date (UTC)"),
		yaxis = attr(title="Relative aperture sum"),
		title = "Source light curves",
		legend_title_text = "Source",
	)
	
	relayout!(p, layout)

	p
end

# ╔═╡ 17eb5723-71f4-4344-b1b1-41b894e7582b
md"""
And divide by a sample comparison star  (the first one):
"""

# ╔═╡ 59392770-f59e-4188-a675-89c2f2fc67d9
let
	sc = scatter(x=df_phot.t, y=df_phot.x1 ./ df_phot.x2, mode = :markers,)

	layout = Layout(
		xaxis = attr(title="Date (UTC)"),
		yaxis = attr(title="Relative aperture sum"),
		title = "W UMa divided light curve",
		legend_title_text = "Source",
	)
	
	plot(sc, layout)
end

# ╔═╡ e34ceb7c-1584-41ce-a5b5-3532fac3c03d
md"""
### Wrapping up

We now have a light curve of an eclipsing binary captured at the predicted time! By eye, totality looks to have lasted for about half an hour, and the total eclipse duration looks to be close to the three hours estimated by the ephemeris. Not too bad for a quick observation taken from a backyard in the middle of a light polluted city.

Since the total period for this system is about 8 hours, we only caught one of the eclipses, in this case the secondary eclipse. With a more careful treatment of the calibration and data reduction procedures, we might also be able to measure the eclipse depth as well as get a more precise estimate on the "time of minimum" (ToM). The former allows us to determine the size of the eclipsing object relative to its companion, and the latter is the precise time that the two objects are exactly aligned. Measuring the ToM over time create so-called "[O-C curves](https://www.aavso.org/analysis-times-minima-o-c-diagram)", or observed minus calculated (predicted) times over time, which allow us to not only measure the periods of binary systems, but also characterize the stellar and orbital evolution of these dynamic systems.
"""

# ╔═╡ 276ff16f-95f1-44eb-971d-db65e8821e59
md"""
## Extensions 🌱
"""

# ╔═╡ 934b1888-0e5c-4dcb-a637-5c2f813161d4
md"""
### Other systematics

Although this was a fairly bright target with a relatively large [signal-to-noise ratio](http://spiff.rit.edu/classes/ast613/lectures/signal/signal_illus.html), its resulting light curve still contains systematics that can be addressed.
"""

# ╔═╡ c5286692-2610-414d-97b7-ffab0bd485a7
md"""
### Observing other eclipsing binary systems

The AAVSO has a great [web interface](https://targettool.aavso.org/) for finding other potential eclipsing binary targets. Below, we briefly show how this could be accessed in a programmatic fashion using [their API](https://targettool.aavso.org/TargetTool/api). If there is interest, we may publish a separate lab on just this topic.
"""

# ╔═╡ 4a6a8956-f6e5-433a-a87b-056a5123ffbc
md"""
We start by [creating an account](https://targettool.aavso.org/init/default/user/register?_next=/init/default/index) on AAVSO. This will allow us to access their API and set our observing location. Once we are logged in, our API key will be displayed as a string of numbers and letters across the top of the [API webpage](https://targettool.aavso.org/TargetTool/api). Copy this key into a text file in your `data` folder, and name it `.aavso_key`. Select the `Query` button below to submit your query to AAVSO.
"""

# ╔═╡ 502fe5dd-d55a-450e-9209-60dc05f395dc
@bind submit_query Button("Submit Query")

# ╔═╡ 14998fe7-8e22-4cd4-87c6-9a5334d218ed
begin
	submit_query
	username = if isfile("data/.aavso_key")
		@debug "API key found"
		readline("data/.aavso_key")
	else
		@debug "No API key found"
		""
	end
end;

# ╔═╡ 4a779bd1-bcf3-41e1-af23-ed00d29db46f
md"""
!!! note
	This is your personal key. Do not share this with others.
"""

# ╔═╡ 7f9c4c42-26fc-4d02-805f-97732032b272
if !isempty(username)
	md"""
	We are now ready to query AAVSO for eclipsing binaries observable from our location. Using the [HTTP.jl](https://juliaweb.github.io/HTTP.jl/stable/) package, we send our query using the following format:

	```julia
	HTTP.get(url; query)
	```
	
	where `url` is entry point into the API (essentially what we would manually type into our browser window):
	
	```julia
	url = "https://{your api key here}:api_token@targettool.aavso.org/TargetTool/api/v1/targets"
	```
	
	and `query` is a key, value map (dictionary) of settings that we would like to pass to the API:

	```julia
	query = (
		# :latitude => 37.76329102360394,
		# :longitude => -122.41190624779506,
		:obs_section => "eb",
		:observable => true,
		:orderby => "period",
	)
	```
	
	Below is a list from the API page of what each of the inputs mean:

	!!! tip ""
		`obs_section` An array with observing sections of interest. You may use one or more of: ac,ep,cv,eb,spp,lpv,yso,het,misc,all. Default is \['ac'\] (Alerts & Campaigns).
		
		`observable` If true, filters out targets which are visible at the telescope location during the following nighttime period. Default is false.
		
		`orderby` Order by any of the output fields below, except for observability\_times and solar\_conjunction.
		
		`reverse` If true, reverses the order. Default is false.
		
		`latitude` Latitude of telescope. South is negative, North is positive. If not provided, the user's settings are assumed.
		
		`longitude` Longitude of telescope. West is negative, East is positive. If not provided, the user's settings are assumed.
		
		`targetaltitude` Minimum altitude that the telescope can observe in degrees relative to the horizon. If not provided, the user's settings are assumed.
		
		`sunaltitude` Altitude of sun at dusk and dawn in degrees. If not provided, the user's settings are assumed.
	"""
end

# ╔═╡ e927297b-9d63-4448-8245-4d73d1fbff27
md"""
Feel free to uncomment the lat/long fields below to override the default location set in your profile, or add any additional settings. We store our query in a [DataFrame](https://dataframes.juliadata.org/stable/) to view the first 10 results:
"""

# ╔═╡ 399f53c5-b654-4330-9ead-4d795917b03b
if !isempty(username)
	df_all = let
		api = "targettool.aavso.org/TargetTool/api/v1/targets"
		url = "https://$(username):api_token@$(api)"
		query = (
			# :latitude => 37.76329102360394,
			# :longitude => -122.41190624779506,
			:obs_section => "eb",
			# :observable => true,
			:orderby => "period",
		)
		r = HTTP.get(url; query)
		
		# The table under the `target` field of the JSONTable does not
		# seem to convert nulls to missings, so using the raw string directly instead
		DataFrame(jsontable(chop(String(r.body); head=12)))
	end
end;

# ╔═╡ c5e95837-fd89-4da2-b480-13f5ed788fb6
msg(md"""
!!! tip ""

	This is Julia's way of interpolating strings. For example:
	
	```julia
	animal = "dogs"
	"I like $(animal)!" # I like dogs!
	```
"""; title=md"What is `$()`?")

# ╔═╡ 29197489-441c-440d-9ce2-3dbd17fa53fc
msg(md"""
!!! tip ""
	We are using the [PrettyTables.jl](https://ronisbr.github.io/PrettyTables.jl/stable/) package to make the output of our DataFrames look a bit nicer in the browser. Try right clicking on the function to see where it is defined.
"""; title=md"What is `pretty`?")

# ╔═╡ f2c89a20-09d5-47f4-8f83-e59477723d95
!isempty(username) && nrow(df_all) # Total number of targets in our list

# ╔═╡ a00cbbfc-56ce-413a-a7b8-13de8541fa6f
if !isempty(username)
	md"""
	It looks like we have $(nrow(df_all)) hits, great! Let's filter these using some convenience syntax from [DataFramesMeta.jl](https://juliadata.org/DataFramesMeta.jl/stable/) to subset for targets that are easily observable, i.e., with our following criteria:

	1. Large change in brightness (at least half a mag)
	2. Fairly short period (period < 3 days)
	3. Includes an ephemeris (the `other_info` column must include this link)

	!!! note
		We also prioritize dimmer targets (V > 9.0). The reason for this is that we are taking a timeseries over the course of hours, which would lead to an unfeasable number of total science frames taken if the exposure time for each one needed to be dialed down for bright targets. Instead, we fix our exposure time to the maximum on eVscopes (4 seconds), and select targets that would not be overexposed at this level.
	
	Lastly, we select the columns that we care about and make some visual transforms for convenience (e.g., including units, converting decimal RA and Dec to `[h m s]`, and `[° ' "]` format, respectively, for easy copy-pasting into the Unistellar app):
	"""
end

# ╔═╡ fd7a53d1-2c6d-4d6a-b546-5c766c9a39d7
md"""
#### Convenience functions
"""

# ╔═╡ 46e6bba9-0c83-47b7-be17-f41301efa18e
function to_hms(ra_deci)
	hms = round.(deg2hms(ra_deci); digits=2)
	format_angle(hms; delim=["h ", "m ", "s"])
end

# ╔═╡ 77544f9e-6053-4ed6-aa9a-4e7a54ca41d9
function to_dms(ra_deci)
	dms = round.(deg2dms(ra_deci); digits=2)
	format_angle(dms; delim=["° ", "' ", "\""])
end

# ╔═╡ 3242f19a-83f7-4db6-b2ea-6ca3403e1039
function get_url(s)
	url = @chain s begin
		split("Ephemeris info ")
		last
		split("]]")
		first
	end
end

# ╔═╡ 1e5596fb-7dca-408b-afbd-6ca2e2487d75
get_shapes(aps; line_color=:lightgreen) = [
	circle(ap.x - ap.r/2, ap.x + ap.r/2, ap.y - ap.r/2, ap.y + ap.r/2;
		line_color,
	)
	for ap in aps
]

# ╔═╡ 2ea12676-7b5e-444e-8025-5bf9c05d0e2d
function ephem(url)
	st = scrape_tables(url)
	ephem_blob = st[3].rows
	if length(ephem_blob[2]) != 4
		error("Expected ephemeris to have Epoch, Start, Mid, and End. Received: ", ephem_blob[2])
	end
	ephem_title, ephem_data... = filter(x -> length(x) == 4, ephem_blob)
	return ephem_title, ephem_data
end

# ╔═╡ d359625e-5a95-49aa-86e4-bc65299dd92a
function deep_link(;
	mission = "transit",
	ra = 0.0,
	dec = 0.0,
	c = 4_000,
	et = 4_000,
	g = 0.0,
	d = 0.0,
	t = 0.0,
	scitag = "scitag",
)
	link = join([
		"unistellar://science/$(mission)?ra=$(ra)",
		"dec=$(dec)",
		"c=$(c)",
		"et=$(et)",
		"g=$(g)",
		"d=$(d)",
		"t=$(t)",
		"scitag=$(scitag)",
	], '&')

	Markdown.parse("[link]($(link))")
end

# ╔═╡ 829cde81-be03-4a9f-a853-28f84923d493
# Make the table view a bit nicer in the browser
pretty(df) = DataFrames.PrettyTables.pretty_table(HTML, df;
	maximum_columns_width = "max-width",
	show_subheader = false,
	header_alignment = :c,
)

# ╔═╡ edda8d09-ec46-4a0b-b1b2-b1289ee5456e
!isempty(username) && first(df_all, 10) |> pretty

# ╔═╡ 1d2bedb1-509d-4956-8e5a-ad1c0f1ffe26
md"""
### Determining observation parameters

Once a target has been found, here's how we might estimate an observing setup for it based on the [Unistellar Exposure Time and Gain Calculator](https://docs.google.com/spreadsheets/d/1niBg5LOkWyR8lCCOOcIo6OHt5kwlc3vnsBsazo7YfXQ/edit#gid=0).
"""

# ╔═╡ 9c482134-6336-4e72-9d30-87080ebae671
@bind target PlutoUI.combine() do Child
	cm"""
	!!! tip "Observation inputs"
		Enter your target's visual magnitude and desired exposure time (in milliseconds) below:
	
		
		|``V_\mathrm{mag}``|``t_\mathrm{exp}``|
		|------------------|------------------|
		|$(Child(:v_mag, NumberField(1:0.1:20; default=11.7)))|$(Child(:t_exp, NumberField(100:100:4_000; default=3_200))) (ms)
	"""
end

# ╔═╡ f290d98e-5a8a-44f2-bee5-b93738abe9af
# Keep these values untouched
const baseline = (
	v_mag = 11.7, # V (mag)
	t_exp = 3200.0, # Exptime (ms)
	gain = 25.0, # Gain (dB)
	peak_px = 3000, # Peak Pixel ADU
)

# ╔═╡ 3c601844-3bb9-422c-ab1e-b40f7e7cb0df
function flux_factor(target, baseline)
	f_mag = (target.v_mag - baseline.v_mag) / -2.5 |> exp10
	f_exp = target.t_exp / baseline.t_exp
	return f_mag * f_exp 
end

# ╔═╡ f26f890b-5924-497c-85a3-eff924d0470b
# Maximum gain
max_gain(baseline, f) = baseline.gain - log10(f) / log10(1.122)

# ╔═╡ 95a67d04-0a32-4e55-ac2f-d004ecc9ca84
# Recommended gain
rec_gain(g) = Int(round(g, RoundDown) - 1.0)

# ╔═╡ 6cec1700-f2de-4e80-b26d-b23b5f7f1823
if !isempty(username)
	df_candidates = @chain df_all begin
		dropmissing
		@rsubset begin
			:min_mag > 9.0 &&
			:min_mag - :max_mag ≥ 0.5 &&
			:min_mag_band == "V" && :max_mag_band == "V" &&
			:period ≤ 3.0 &&
			startswith(:other_info, "[[Ephemeris")
		end
		
		@rtransform :ephem_url = get_url(:other_info)
		
		@rtransform begin
			:star_name
			:period = round(Minute, :period * u"d") |> canonicalize
			:ra = to_hms(:ra)
			:ra_deci = :ra
			:dec = to_dms(:dec)
			:dec_deci = :dec
			:min_mag
			# :min_mag_band
			:max_mag
			:V_mag = (:min_mag + :max_mag) / 2.0
			# :max_mag_band
			# :var_type
			# :min_mag
			# :max_mag
			:ephem_link = Markdown.parse("[link]($(:ephem_url))")
			:ephem_url
			# :unix_timestamp = (last ∘ first)(:observability_times)
		end
		@rtransform begin
			:gain = let
				target = (v_mag=:V_mag, t_exp=4_000) # Default to max exp
				f_factor = flux_factor(target, baseline) 
				gain_max = max_gain(baseline, f_factor)
				rec_gain(gain_max)
			end
		end
	
		sort(:period)

		@select begin
			:star_name
			:period
			:ra
			:ra_deci
			:dec
			:dec_deci
			:V_mag
			:gain
			:ephem_link
			:ephem_url
		end
	end
end

# ╔═╡ 4042bc32-1a14-4408-974d-7405fd8c8ccc
!isempty(username) && df_candidates |> pretty

# ╔═╡ 95f9803a-86df-4517-adc8-0bcbb0ff6fbc
if !isempty(username)
	md"""
	We now have $(nrow(df_candidates)) prime candidates that we can plan our observations for. Clicking on the `ephem_link` in the last column should take us to a table on AAVSO with the predicted eclipse times for the next month. For convenience, we can also select one of the targets below to generate a table of deep links:

	!!! note
		This will only work for targets that have a complete ephemeris. All times are in UTC.
	"""
end

# ╔═╡ a5f3915c-6eed-480d-9aed-8fdd052a324a
!isempty(username) && @bind star_name Select(df_candidates.star_name)

# ╔═╡ 3f548bb1-37b0-48b7-a35c-d7701405a64e
if !isempty(username)
	df_selected = @rsubset df_candidates :star_name == star_name
end

# ╔═╡ 8a39fbbb-6b5b-4744-a875-469c289242fb
if !isempty(username)
	df_ephem = let
		ephem_title, ephem_data = ephem(only(df_selected.ephem_url))
		df = DataFrame(
			stack(ephem_data; dims=1),
			ephem_title,
		)
	
		fmt = dateformat"dd u YYYY HH:MM"
		@chain df begin
			@rtransform begin
				# :Epoch = parse(Float64, :Epoch)
				:star_name = only(df_selected.star_name)
				:Start = DateTime(:Start, fmt)
				:Mid = DateTime(:Mid, fmt)
				:End = DateTime(:End, fmt)
				
			end
			
			@rtransform begin
				:Duration = canonicalize(:End - :Start)
				:Duration_s = Second(:End - :Start).value
				:unix_timestamp_ms = 1_000 * datetime2unix(:Mid)
			end
		end
	end
end

# ╔═╡ 31c23e2b-1a2d-41aa-81c1-22868e241f7e
if !isempty(username)
	df_obs = let
		df = leftjoin(df_selected, df_ephem; on=:star_name)
		fmt = dateformat"yymmdd"
		@rselect df begin
			:star_name
			:Start
			:Mid
			:End
			:Duration
			:deep_link = deep_link(;
				ra = :ra_deci,
				dec = :dec_deci,
				g = :gain,
				d = round(Int, 1.5 * :Duration_s),
				t = round(Int, :unix_timestamp_ms),
				scitag = join([
					"e",
					Dates.format(:Mid, fmt),
					replace(:star_name, " " => ""),
				]),
			)
		end
	end

	df_obs |> pretty
end

# ╔═╡ 90b6ef16-7853-46e1-bbd6-cd1a904c442a
let
	f_factor = flux_factor(target, baseline)
	gain_max = max_gain(baseline, f_factor)
	gain_recommended = rec_gain(gain_max)

	@debug "Observing params" f_factor gain_max gain_recommended
end

# ╔═╡ 7d99f9b9-f4ea-4d4b-99b2-608bc491f05c
md"""
---
## Notebook setup 🔧
"""

# ╔═╡ 2baf0cba-7ef9-4dd5-bc68-bcdac7753b30
md"""
### Convenience functions and settings
"""

# ╔═╡ ab2bac2b-b2ba-4eaa-8444-439485627bad
# const width = round(Int, size(img_sci, 1) / 4) + 100

# ╔═╡ 48f4cdf3-b3d7-4cd6-8071-78292fec0db9
# const height = round(Int, width * size(img_sci, 2) / size(img_sci, 1))

# ╔═╡ 285a56b7-bb3e-4929-a853-2fc69c77bdcb
const clims = (150, 700);

# ╔═╡ a984c96d-273e-4d6d-bab8-896f14a79103
TableOfContents(; depth=4)

# ╔═╡ 21e828e5-00e4-40ce-bff5-60a17439bf44
# Helpful for not having ginormous plot objects
r2(img) = (restrict ∘ restrict)(img)

# ╔═╡ e35d4be7-366d-4ca5-a89a-5de24e4c6677
function htrace(img;
	zmin = 2_400,
	zmax = 3_200,
	title = "ADU",
	restrict = true,
)
	if restrict
		img_small = r2(img)
	else
		img_small = img
	end

	img_small = permutedims(img_small)
	
	heatmap(;
		x = img_small.dims[1].val,
		y = img_small.dims[2].val,
		z = img_small.data,
		zmin,
		zmax,
		colorbar = attr(; title),
		colorscale = :Cividis,
	)
end

# ╔═╡ a3bcad72-0e6c-43f8-a08d-777a154190d8
function circ(ap; line_color=:lightgreen)
	circle(
		ap.x - ap.r, # x_min
		ap.x + ap.r, # x_max
		ap.y - ap.r, # y_min
		ap.y + ap.r; # y_max
		line_color,
	)
end

# ╔═╡ 2e59cc0d-e477-4826-b8b6-d2d68c8592a9
# Convert to plotly objects for plotting
shapes = [
	circ(ap_target),
	circ(ap_comp1; line_color=:orange),
	circ(ap_comp2; line_color=:orange),
];

# ╔═╡ 8da80446-84d7-44bb-8122-874b4c9514f4
timestamp(img) = header(img)["DATE-OBS"]

# ╔═╡ 24256769-2274-4b78-8445-88ec4536c407
function plot_img(i, img; restrict=true)
	hm = htrace(img; restrict)
	
	l = Layout(;
		#width,
		#height,
		title = string("Frame $(i): ", timestamp(img)),
		xaxis = attr(title="X", constrain=:domain),
		yaxis = attr(title="Y", scaleanchor=:x, constrain=:domain),
		uirevision = 1,
	)

	plot(hm, l)
end

# ╔═╡ 86e53a41-ab0d-4d9f-8a80-855949847ba2
let
	p = plot_img(frame_i, imgs_sci[frame_i])
	relayout!(p; shapes)
	p
end

# ╔═╡ f3683998-543c-4bc4-8b73-fc1de6a6a955
let
	p = plot_img(frame_i_aligned, imgs_sci_aligned[frame_i_aligned])
	relayout!(p; shapes)
	p
end

# ╔═╡ 5b079ce8-3b28-4fe7-8df2-f576c2c948f5
md"""
### Packages
"""

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
AstroAngles = "5c4adb95-c1fc-4c53-b4ea-2a94080c53d2"
AstroImages = "fe3fc30c-9b16-11e9-1c73-17dabf39f4ad"
CCDReduction = "b790e538-3052-4cb9-9f1f-e05859a455f5"
CommonMark = "a80b9123-70ca-4bc0-993e-6e3bcb318db6"
CondaPkg = "992eb4ea-22a4-4c89-a5bb-47a3300528ab"
DataDeps = "124859b0-ceae-595e-8997-d05f6a7a8dfe"
DataFramesMeta = "1313f7d8-7da2-5740-9ea0-a2ca25f37964"
Dates = "ade2ca70-3891-5945-98fb-dc099432e06a"
HTTP = "cd3eb016-35fb-5094-929b-558a96fad6f3"
ImageCore = "a09fc81d-aa75-5fe9-8630-4744c3626534"
JSONTables = "b9914132-a727-11e9-1322-f18e41205b0b"
Photometry = "af68cb61-81ac-52ed-8703-edc140936be4"
PlutoPlotly = "8e989ff0-3d88-8e9f-f020-2b208a939ff0"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
PythonCall = "6099a3de-0909-46bc-b1f4-468b9a2dfc0d"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
TableScraper = "3d876f86-fca9-45cb-9864-7207416dc431"
Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[compat]
AstroAngles = "~0.1.3"
AstroImages = "~0.4.2"
CCDReduction = "~0.2.2"
CommonMark = "~0.8.12"
CondaPkg = "~0.2.22"
DataDeps = "~0.7.13"
DataFramesMeta = "~0.15.2"
HTTP = "~1.10.6"
ImageCore = "~0.9.4"
JSONTables = "~1.0.3"
Photometry = "~0.9.0"
PlutoPlotly = "~0.4.6"
PlutoUI = "~0.7.59"
PythonCall = "~0.9.20"
TableScraper = "~0.1.4"
Unitful = "~1.20.0"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.11.5"
manifest_format = "2.0"
project_hash = "521f9e293cbfe090aaf2938682d8c49d88819e04"

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

[[deps.AbstractTrees]]
git-tree-sha1 = "2d9c9a55f9c93e8887ad391fbae72f8ef55e1177"
uuid = "1520ce14-60c1-5f80-bbc7-55ef81b5835c"
version = "0.4.5"

[[deps.Accessors]]
deps = ["CompositionsBase", "ConstructionBase", "Dates", "InverseFunctions", "MacroTools"]
git-tree-sha1 = "0ba8f4c1f06707985ffb4804fdad1bf97b233897"
uuid = "7d9f7c33-5ae7-4f3b-8dc6-eff91059b697"
version = "0.1.41"

    [deps.Accessors.extensions]
    AxisKeysExt = "AxisKeys"
    IntervalSetsExt = "IntervalSets"
    LinearAlgebraExt = "LinearAlgebra"
    StaticArraysExt = "StaticArrays"
    StructArraysExt = "StructArrays"
    TestExt = "Test"
    UnitfulExt = "Unitful"

    [deps.Accessors.weakdeps]
    AxisKeys = "94b1ba4f-4ee9-5380-92f1-94cde586c3c5"
    IntervalSets = "8197267c-284f-5f27-9208-e0e47529a953"
    LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
    Requires = "ae029012-a4dd-5104-9daa-d747884805df"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"
    StructArrays = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
    Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
    Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[[deps.Adapt]]
deps = ["LinearAlgebra", "Requires"]
git-tree-sha1 = "cde29ddf7e5726c9fb511f340244ea3481267608"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "3.7.2"
weakdeps = ["StaticArrays"]

    [deps.Adapt.extensions]
    AdaptStaticArraysExt = "StaticArrays"

[[deps.ArgCheck]]
git-tree-sha1 = "680b3b8759bd4c54052ada14e52355ab69e07876"
uuid = "dce04be8-c92d-5529-be00-80e4d2c0e197"
version = "2.4.0"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.2"

[[deps.ArrayInterface]]
deps = ["Adapt", "LinearAlgebra", "Requires", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "c5aeb516a84459e0318a02507d2261edad97eb75"
uuid = "4fba245c-0d91-5ea0-9b3e-6abc04ee57a9"
version = "7.7.1"

    [deps.ArrayInterface.extensions]
    ArrayInterfaceBandedMatricesExt = "BandedMatrices"
    ArrayInterfaceBlockBandedMatricesExt = "BlockBandedMatrices"
    ArrayInterfaceCUDAExt = "CUDA"
    ArrayInterfaceGPUArraysCoreExt = "GPUArraysCore"
    ArrayInterfaceStaticArraysCoreExt = "StaticArraysCore"
    ArrayInterfaceTrackerExt = "Tracker"

    [deps.ArrayInterface.weakdeps]
    BandedMatrices = "aae01518-5342-5314-be14-df237901396f"
    BlockBandedMatrices = "ffab5731-97b5-5995-9138-79e8c1846df0"
    CUDA = "052768ef-5323-5732-b1bb-66c8b64840ba"
    GPUArraysCore = "46192b85-c4d5-4398-a991-12ede77f4527"
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
git-tree-sha1 = "09dd0aed7460a51d2f35af92255a4f572b8c2a19"
uuid = "fe3fc30c-9b16-11e9-1c73-17dabf39f4ad"
version = "0.4.2"

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

[[deps.BangBang]]
deps = ["Accessors", "ConstructionBase", "InitialValues", "LinearAlgebra", "Requires"]
git-tree-sha1 = "e2144b631226d9eeab2d746ca8880b7ccff504ae"
uuid = "198e06fe-97b7-11e9-32a5-e1d131e6ad66"
version = "0.4.3"

    [deps.BangBang.extensions]
    BangBangChainRulesCoreExt = "ChainRulesCore"
    BangBangDataFramesExt = "DataFrames"
    BangBangStaticArraysExt = "StaticArrays"
    BangBangStructArraysExt = "StructArrays"
    BangBangTablesExt = "Tables"
    BangBangTypedTablesExt = "TypedTables"

    [deps.BangBang.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"
    StructArrays = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
    Tables = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
    TypedTables = "9d95f2ec-7b3d-5a63-8d20-e2491e220bb9"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"
version = "1.11.0"

[[deps.BaseDirs]]
git-tree-sha1 = "cb25e4b105cc927052c2314f8291854ea59bf70a"
uuid = "18cc8868-cbac-4acf-b575-c8ff214dc66f"
version = "1.2.4"

[[deps.Baselet]]
git-tree-sha1 = "aebf55e6d7795e02ca500a689d326ac979aaf89e"
uuid = "9718e550-a3fa-408a-8086-8db961cd8217"
version = "0.1.1"

[[deps.BenchmarkTools]]
deps = ["Compat", "JSON", "Logging", "Printf", "Profile", "Statistics", "UUIDs"]
git-tree-sha1 = "e38fbc49a620f5d0b660d7f543db1009fe0f8336"
uuid = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
version = "1.6.0"

[[deps.BitFlags]]
git-tree-sha1 = "0691e34b3bb8be9307330f88d1a3c3f25466c24d"
uuid = "d1d4a3ce-64b1-5f1a-9ba4-7e7e69966f35"
version = "0.1.9"

[[deps.Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1b96ea4a01afe0ea4090c5c8039690672dd13f2e"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.9+0"

[[deps.CCDReduction]]
deps = ["DataFrames", "FITSIO", "LazyStack", "ResumableFunctions", "Statistics"]
git-tree-sha1 = "516a5374543571ab09a32a18d45368ad018e552f"
uuid = "b790e538-3052-4cb9-9f1f-e05859a455f5"
version = "0.2.2"

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

[[deps.CRlibm]]
deps = ["CRlibm_jll"]
git-tree-sha1 = "32abd86e3c2025db5172aa182b982debed519834"
uuid = "96374032-68de-5a5b-8d9e-752f78720389"
version = "1.0.1"

[[deps.CRlibm_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e329286945d0cfc04456972ea732551869af1cfc"
uuid = "4e9b3aee-d8a1-5a3d-ad8b-7d824db253f0"
version = "1.0.1+0"

[[deps.Cascadia]]
deps = ["AbstractTrees", "Gumbo"]
git-tree-sha1 = "c0769cbd930aea932c0912c4d2749c619a263fc1"
uuid = "54eefc05-d75b-58de-a785-1a3403f0919f"
version = "1.0.2"

[[deps.CatIndices]]
deps = ["CustomUnitRanges", "OffsetArrays"]
git-tree-sha1 = "a0f80a09780eed9b1d106a1bf62041c2efc995bc"
uuid = "aafaddc9-749c-510e-ac4f-586e18779b91"
version = "0.2.2"

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

[[deps.CodecBzip2]]
deps = ["Bzip2_jll", "TranscodingStreams"]
git-tree-sha1 = "84990fa864b7f2b4901901ca12736e45ee79068c"
uuid = "523fee87-0ab8-5b00-afb7-3ecf72e48cfd"
version = "0.8.5"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "bce6804e5e6044c6daab27bb533d1295e4a2e759"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.6"

[[deps.ColorSchemes]]
deps = ["ColorTypes", "ColorVectorSpace", "Colors", "FixedPointNumbers", "PrecompileTools", "Random"]
git-tree-sha1 = "b5278586822443594ff615963b0c09755771b3e0"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.26.0"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "b10d0b65641d57b8b4d5e234446582de5047050d"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.5"

[[deps.ColorVectorSpace]]
deps = ["ColorTypes", "FixedPointNumbers", "LinearAlgebra", "SpecialFunctions", "Statistics", "TensorCore"]
git-tree-sha1 = "600cc5508d66b78aae350f7accdb58763ac18589"
uuid = "c3611d14-8923-5661-9e6a-0046d554d3a4"
version = "0.9.10"

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

[[deps.CommonSubexpressions]]
deps = ["MacroTools"]
git-tree-sha1 = "cda2cfaebb4be89c9084adaca7dd7333369715c5"
uuid = "bbf7d656-a473-5ed7-a52c-81e309532950"
version = "0.3.1"

[[deps.CommonWorldInvalidations]]
git-tree-sha1 = "ae52d1c52048455e85a387fbee9be553ec2b68d0"
uuid = "f70d9fcc-98c5-4d4a-abd7-e4cdeebd8ca8"
version = "1.0.0"

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

[[deps.CompositionsBase]]
git-tree-sha1 = "802bb88cd69dfd1509f6670416bd4434015693ad"
uuid = "a33af91c-f02d-484b-be07-31d278c5ca2b"
version = "0.1.2"
weakdeps = ["InverseFunctions"]

    [deps.CompositionsBase.extensions]
    CompositionsBaseInverseFunctionsExt = "InverseFunctions"

[[deps.ComputationalResources]]
git-tree-sha1 = "52cb3ec90e8a8bea0e62e275ba577ad0f74821f7"
uuid = "ed09eef8-17a6-5b46-8889-db040fac31e3"
version = "0.3.2"

[[deps.ConcurrentUtilities]]
deps = ["Serialization", "Sockets"]
git-tree-sha1 = "f36e5e8fdffcb5646ea5da81495a5a7566005127"
uuid = "f0e56b4a-5159-44fe-b623-3e5288b988bb"
version = "2.4.3"

[[deps.CondaPkg]]
deps = ["JSON3", "Markdown", "MicroMamba", "Pidfile", "Pkg", "Preferences", "TOML"]
git-tree-sha1 = "905244d4b8d2319783a39df4e7c7eb9e9bb022d8"
uuid = "992eb4ea-22a4-4c89-a5bb-47a3300528ab"
version = "0.2.24"

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
git-tree-sha1 = "f9d7112bfff8a19a3a4ea4e03a8e6a91fe8456bf"
uuid = "150eb455-5306-5404-9cee-2592286d6298"
version = "0.6.3"

[[deps.CovarianceEstimation]]
deps = ["LinearAlgebra", "Statistics", "StatsBase", "TSVD", "WoodburyMatrices"]
git-tree-sha1 = "834e99e29fe618f9076bf0867a068508fbc0b1f8"
uuid = "587fd27a-f159-11e8-2dae-1979310e6154"
version = "0.2.13"

[[deps.Crayons]]
git-tree-sha1 = "249fe38abf76d48563e2f4556bebd215aa317e15"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.1.1"

[[deps.CustomUnitRanges]]
git-tree-sha1 = "1a3f97f907e6dd8983b744d2642651bb162a3f7a"
uuid = "dc8bdbbb-1ca9-579f-8c36-e416f6a65cce"
version = "1.0.2"

[[deps.DataAPI]]
git-tree-sha1 = "abe83f3a2f1b857aac70ef8b269080af17764bbe"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.16.0"

[[deps.DataDeps]]
deps = ["HTTP", "Libdl", "Reexport", "SHA", "Scratch", "p7zip_jll"]
git-tree-sha1 = "8ae085b71c462c2cb1cfedcb10c3c877ec6cf03f"
uuid = "124859b0-ceae-595e-8997-d05f6a7a8dfe"
version = "0.7.13"

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

[[deps.DefineSingletons]]
git-tree-sha1 = "0fba8b706d0178b4dc7fd44a96a92382c9065c2c"
uuid = "244e2a9f-e319-4986-a169-4d1fe445cd52"
version = "0.1.2"

[[deps.DelimitedFiles]]
deps = ["Mmap"]
git-tree-sha1 = "9e2f36d3c96a820c678f2f1f1782582fcf685bae"
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"
version = "1.9.1"

[[deps.Dictionaries]]
deps = ["Indexing", "Random", "Serialization"]
git-tree-sha1 = "1cdab237b6e0d0960d5dcbd2c0ebfa15fa6573d9"
uuid = "85a47980-9c8c-11e8-2b9f-f7ca1fa99fb4"
version = "0.4.4"

[[deps.DiffResults]]
deps = ["StaticArraysCore"]
git-tree-sha1 = "782dd5f4561f5d267313f23853baaaa4c52ea621"
uuid = "163ba53b-c6d8-5494-b064-1a9d43ac40c5"
version = "1.1.0"

[[deps.DiffRules]]
deps = ["IrrationalConstants", "LogExpFunctions", "NaNMath", "Random", "SpecialFunctions"]
git-tree-sha1 = "23163d55f885173722d1e4cf0f6110cdbaf7e272"
uuid = "b552c78f-8df3-52c6-915a-8e097449b14b"
version = "1.15.1"

[[deps.DimensionalData]]
deps = ["Adapt", "ArrayInterface", "ConstructionBase", "Dates", "Extents", "IntervalSets", "IteratorInterfaceExtensions", "LinearAlgebra", "PrecompileTools", "Random", "RecipesBase", "SparseArrays", "Statistics", "TableTraits", "Tables"]
git-tree-sha1 = "8a6e9c0ac3a861b983af862cefabc12519884a13"
uuid = "0703355e-b756-11e9-17c0-8b28908087d0"
version = "0.24.13"

[[deps.Distances]]
deps = ["LinearAlgebra", "Statistics", "StatsAPI"]
git-tree-sha1 = "c7e3a542b999843086e2f29dac96a618c105be1d"
uuid = "b4f34e82-e78d-54a5-968a-f98e89d6e8f7"
version = "0.10.12"
weakdeps = ["ChainRulesCore", "SparseArrays"]

    [deps.Distances.extensions]
    DistancesChainRulesCoreExt = "ChainRulesCore"
    DistancesSparseArraysExt = "SparseArrays"

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

[[deps.EnumX]]
git-tree-sha1 = "bdb1942cd4c45e3c678fd11569d5cccd80976237"
uuid = "4e289a0a-7415-4d19-859d-a7e5c4648b56"
version = "1.0.4"

[[deps.ErrorfreeArithmetic]]
git-tree-sha1 = "d6863c556f1142a061532e79f611aa46be201686"
uuid = "90fa49ef-747e-5e6f-a989-263ba693cf1a"
version = "0.5.2"

[[deps.ExceptionUnwrapping]]
deps = ["Test"]
git-tree-sha1 = "d36f682e590a83d63d1c7dbd287573764682d12a"
uuid = "460bff9d-24e4-43bc-9d9f-a8973cb893f4"
version = "0.1.11"

[[deps.ExprTools]]
git-tree-sha1 = "27415f162e6028e81c72b82ef756bf321213b6ec"
uuid = "e2ba6199-217a-4e67-a87a-7c52f15ade04"
version = "0.1.10"

[[deps.Extents]]
git-tree-sha1 = "063512a13dbe9c40d999c439268539aa552d1ae6"
uuid = "411431e0-e8b7-467b-b5e0-f676ba4f2910"
version = "0.1.5"

[[deps.FFTViews]]
deps = ["CustomUnitRanges", "FFTW"]
git-tree-sha1 = "cbdf14d1e8c7c8aacbe8b19862e0179fd08321c2"
uuid = "4f61f5a4-77b1-5117-aa51-3ab5ef4ef0cd"
version = "0.3.2"

[[deps.FFTW]]
deps = ["AbstractFFTs", "FFTW_jll", "LinearAlgebra", "MKL_jll", "Preferences", "Reexport"]
git-tree-sha1 = "7de7c78d681078f027389e067864a8d53bd7c3c9"
uuid = "7a1cc6ca-52ef-59f5-83cd-3a7055c09341"
version = "1.8.1"

[[deps.FFTW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4d81ed14783ec49ce9f2e168208a12ce1815aa25"
uuid = "f5851436-0d7a-5f13-b9de-f02708fd171a"
version = "3.3.10+3"

[[deps.FITSIO]]
deps = ["CFITSIO", "Printf", "Reexport", "Tables"]
git-tree-sha1 = "f4243755388de27c018f4bb6b19334e991532e5f"
uuid = "525bcba6-941b-5504-bd06-fd0dc1a4d2eb"
version = "0.16.13"

[[deps.FastRounding]]
deps = ["ErrorfreeArithmetic", "LinearAlgebra"]
git-tree-sha1 = "6344aa18f654196be82e62816935225b3b9abe44"
uuid = "fa42c844-2597-5d31-933b-ebd51ab2693f"
version = "0.3.1"

[[deps.FileIO]]
deps = ["Pkg", "Requires", "UUIDs"]
git-tree-sha1 = "2dd20384bf8c6d411b5c7370865b1e9b26cb2ea3"
uuid = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
version = "1.16.6"
weakdeps = ["HTTP"]

    [deps.FileIO.extensions]
    HTTPExt = "HTTP"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"
version = "1.11.0"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "05882d6995ae5c12bb5f36dd2ed3f61c98cbb172"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.5"

[[deps.ForwardDiff]]
deps = ["CommonSubexpressions", "DiffResults", "DiffRules", "LinearAlgebra", "LogExpFunctions", "NaNMath", "Preferences", "Printf", "Random", "SpecialFunctions"]
git-tree-sha1 = "a2df1b776752e3f344e5116c06d75a10436ab853"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "0.10.38"
weakdeps = ["StaticArrays"]

    [deps.ForwardDiff.extensions]
    ForwardDiffStaticArraysExt = "StaticArrays"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"
version = "1.11.0"

[[deps.GLPK]]
deps = ["GLPK_jll", "MathOptInterface"]
git-tree-sha1 = "1d706bd23e5d2d407bfd369499ee6f96afb0c3ad"
uuid = "60bf3e95-4087-53dc-ae20-288a0d20c6a6"
version = "1.2.1"

[[deps.GLPK_jll]]
deps = ["Artifacts", "GMP_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "6aa6294ba949ccfc380463bf50ff988b46de5bc7"
uuid = "e8aa6df9-e6ca-548a-97ff-1f85fc5b8b98"
version = "5.0.1+1"

[[deps.GMP_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "781609d7-10c4-51f6-84f2-b8444358ff6d"
version = "6.3.0+0"

[[deps.Graphics]]
deps = ["Colors", "LinearAlgebra", "NaNMath"]
git-tree-sha1 = "a641238db938fff9b2f60d08ed9030387daf428c"
uuid = "a2bd30eb-e257-5431-a919-1863eab51364"
version = "1.1.3"

[[deps.Gumbo]]
deps = ["AbstractTrees", "Gumbo_jll", "Libdl"]
git-tree-sha1 = "eab9e02310eb2c3e618343c859a12b51e7577f5e"
uuid = "708ec375-b3d6-5a57-a7ce-8257bf98657a"
version = "0.8.3"

[[deps.Gumbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "29070dee9df18d9565276d68a596854b1764aa38"
uuid = "528830af-5a63-567c-a44a-034ed33b8444"
version = "0.10.2+0"

[[deps.HTTP]]
deps = ["Base64", "CodecZlib", "ConcurrentUtilities", "Dates", "ExceptionUnwrapping", "Logging", "LoggingExtras", "MbedTLS", "NetworkOptions", "OpenSSL", "PrecompileTools", "Random", "SimpleBufferStream", "Sockets", "URIs", "UUIDs"]
git-tree-sha1 = "c67b33b085f6e2faf8bf79a61962e7339a81129c"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "1.10.15"

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

[[deps.IfElse]]
git-tree-sha1 = "debdd00ffef04665ccbb3e150747a77560e8fad1"
uuid = "615f187c-cbe4-4ef1-ba3b-2fcf58d6d173"
version = "0.1.1"

[[deps.ImageAxes]]
deps = ["AxisArrays", "ImageBase", "ImageCore", "Reexport", "SimpleTraits"]
git-tree-sha1 = "2e4520d67b0cef90865b3ef727594d2a58e0e1f8"
uuid = "2803e5a7-5153-5ecf-9a86-9b4c37f5f5ac"
version = "0.6.11"

[[deps.ImageBase]]
deps = ["ImageCore", "Reexport"]
git-tree-sha1 = "b51bb8cae22c66d0f6357e3bcb6363145ef20835"
uuid = "c817782e-172a-44cc-b673-b171935fbb9e"
version = "0.1.5"

[[deps.ImageCore]]
deps = ["AbstractFFTs", "ColorVectorSpace", "Colors", "FixedPointNumbers", "Graphics", "MappedArrays", "MosaicViews", "OffsetArrays", "PaddedViews", "Reexport"]
git-tree-sha1 = "acf614720ef026d38400b3817614c45882d75500"
uuid = "a09fc81d-aa75-5fe9-8630-4744c3626534"
version = "0.9.4"

[[deps.ImageFiltering]]
deps = ["CatIndices", "ComputationalResources", "DataStructures", "FFTViews", "FFTW", "ImageBase", "ImageCore", "LinearAlgebra", "OffsetArrays", "PrecompileTools", "Reexport", "SparseArrays", "StaticArrays", "Statistics", "TiledIteration"]
git-tree-sha1 = "3447781d4c80dbe6d71d239f7cfb1f8049d4c84f"
uuid = "6a3955dd-da59-5b1f-98d4-e7296123deb5"
version = "0.7.6"

[[deps.ImageIO]]
deps = ["FileIO", "IndirectArrays", "JpegTurbo", "LazyModules", "Netpbm", "OpenEXR", "PNGFiles", "QOI", "Sixel", "TiffImages", "UUIDs"]
git-tree-sha1 = "437abb322a41d527c197fa800455f79d414f0a3c"
uuid = "82e4d734-157c-48bb-816b-45c225c6df19"
version = "0.6.8"

[[deps.ImageMetadata]]
deps = ["AxisArrays", "ImageAxes", "ImageBase", "ImageCore"]
git-tree-sha1 = "355e2b974f2e3212a75dfb60519de21361ad3cb7"
uuid = "bc367c6b-8a6b-528e-b4bd-a4b897500b49"
version = "0.9.9"

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

[[deps.Indexing]]
git-tree-sha1 = "ce1566720fd6b19ff3411404d4b977acd4814f9f"
uuid = "313cdc1a-70c2-5d6a-ae34-0150d3930a38"
version = "1.1.1"

[[deps.IndirectArrays]]
git-tree-sha1 = "012e604e1c7458645cb8b436f8fba789a51b257f"
uuid = "9b13fd28-a010-5f03-acff-a1bbcff69959"
version = "1.0.0"

[[deps.Inflate]]
git-tree-sha1 = "d1b1b796e47d94588b3757fe84fbf65a5ec4a80d"
uuid = "d25df0c9-e2be-5dd7-82c8-3ad0b3e990b9"
version = "0.1.5"

[[deps.InitialValues]]
git-tree-sha1 = "4da0f88e9a39111c2fa3add390ab15f3a44f3ca3"
uuid = "22cec73e-a1b8-11e9-2c92-598750a2cf9c"
version = "0.3.1"

[[deps.InlineStrings]]
git-tree-sha1 = "45521d31238e87ee9f9732561bfee12d4eebd52d"
uuid = "842dd82b-1e85-43dc-bf29-5d0ee9dffc48"
version = "1.4.2"

    [deps.InlineStrings.extensions]
    ArrowTypesExt = "ArrowTypes"
    ParsersExt = "Parsers"

    [deps.InlineStrings.weakdeps]
    ArrowTypes = "31f734f8-188a-4ce0-8406-c8a06bd891cd"
    Parsers = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"

[[deps.IntelOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "LazyArtifacts", "Libdl"]
git-tree-sha1 = "0f14a5456bdc6b9731a5682f439a672750a09e48"
uuid = "1d5cc7b8-4909-519e-a0f8-d0f5ad9712d0"
version = "2025.0.4+0"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"
version = "1.11.0"

[[deps.Interpolations]]
deps = ["Adapt", "AxisAlgorithms", "ChainRulesCore", "LinearAlgebra", "OffsetArrays", "Random", "Ratios", "Requires", "SharedArrays", "SparseArrays", "StaticArrays", "WoodburyMatrices"]
git-tree-sha1 = "88a101217d7cb38a7b481ccd50d21876e1d1b0e0"
uuid = "a98d9a8b-a2ab-59e6-89dd-64a1c18fca59"
version = "0.15.1"
weakdeps = ["Unitful"]

    [deps.Interpolations.extensions]
    InterpolationsUnitfulExt = "Unitful"

[[deps.IntervalArithmetic]]
deps = ["CRlibm", "EnumX", "FastRounding", "LinearAlgebra", "Markdown", "Random", "RecipesBase", "RoundingEmulator", "SetRounding", "StaticArrays"]
git-tree-sha1 = "f59e639916283c1d2e106d2b00910b50f4dab76c"
uuid = "d1acc4aa-44c8-5952-acd4-ba5d80a2a253"
version = "0.21.2"

[[deps.IntervalSets]]
git-tree-sha1 = "dba9ddf07f77f60450fe5d2e2beb9854d9a49bd0"
uuid = "8197267c-284f-5f27-9208-e0e47529a953"
version = "0.7.10"
weakdeps = ["Random", "RecipesBase", "Statistics"]

    [deps.IntervalSets.extensions]
    IntervalSetsRandomExt = "Random"
    IntervalSetsRecipesBaseExt = "RecipesBase"
    IntervalSetsStatisticsExt = "Statistics"

[[deps.InverseFunctions]]
git-tree-sha1 = "a779299d77cd080bf77b97535acecd73e1c5e5cb"
uuid = "3587e190-3f89-42d0-90ee-14403ec27112"
version = "0.1.17"
weakdeps = ["Dates", "Test"]

    [deps.InverseFunctions.extensions]
    InverseFunctionsDatesExt = "Dates"
    InverseFunctionsTestExt = "Test"

[[deps.InvertedIndices]]
git-tree-sha1 = "6da3c4316095de0f5ee2ebd875df8721e7e0bdbe"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.3.1"

[[deps.IrrationalConstants]]
git-tree-sha1 = "e2222959fbc6c19554dc15174c81bf7bf3aa691c"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.2.4"

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

[[deps.JSON3]]
deps = ["Dates", "Mmap", "Parsers", "PrecompileTools", "StructTypes", "UUIDs"]
git-tree-sha1 = "1d322381ef7b087548321d3f878cb4c9bd8f8f9b"
uuid = "0f8b85d8-7281-11e9-16c2-39a750bddbf1"
version = "1.14.1"

    [deps.JSON3.extensions]
    JSON3ArrowExt = ["ArrowTypes"]

    [deps.JSON3.weakdeps]
    ArrowTypes = "31f734f8-188a-4ce0-8406-c8a06bd891cd"

[[deps.JSONTables]]
deps = ["JSON3", "StructTypes", "Tables"]
git-tree-sha1 = "13f7485bb0b4438bb5e83e62fcadc65c5de1d1bb"
uuid = "b9914132-a727-11e9-1322-f18e41205b0b"
version = "1.0.3"

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

[[deps.JuMP]]
deps = ["LinearAlgebra", "MacroTools", "MathOptInterface", "MutableArithmetics", "OrderedCollections", "PrecompileTools", "Printf", "SparseArrays"]
git-tree-sha1 = "02b6e65736debc1f47b40b0f7d5dfa0217ee1f09"
uuid = "4076af6c-e467-56ae-b986-b466b2749572"
version = "1.23.6"
weakdeps = ["DimensionalData"]

    [deps.JuMP.extensions]
    JuMPDimensionalDataExt = "DimensionalData"

[[deps.LaTeXStrings]]
git-tree-sha1 = "dda21b8cbd6a6c40d9d02a73230f9d70fed6918c"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.4.0"

[[deps.LazyArtifacts]]
deps = ["Artifacts", "Pkg"]
uuid = "4af54fe1-eca0-43a8-85a7-787d91b784e3"
version = "1.11.0"

[[deps.LazyModules]]
git-tree-sha1 = "a560dd966b386ac9ae60bdd3a3d3a326062d3c3e"
uuid = "8cdb02fc-e678-4876-92c5-9defec4f444e"
version = "0.3.1"

[[deps.LazySets]]
deps = ["Distributed", "GLPK", "IntervalArithmetic", "JuMP", "LinearAlgebra", "Random", "ReachabilityBase", "RecipesBase", "Reexport", "Requires", "SharedArrays", "SparseArrays", "StaticArraysCore"]
git-tree-sha1 = "c46bea04a8a94fb7fa4e3007506601fa34d6a711"
uuid = "b4f0291d-fe17-52bc-9479-3d1a343d9043"
version = "2.14.2"

[[deps.LazyStack]]
deps = ["LinearAlgebra", "NamedDims", "OffsetArrays", "Test", "ZygoteRules"]
git-tree-sha1 = "a8bf67afad3f1ee59d367267adb7c44ccac7fdee"
uuid = "1fad7336-0346-5a1a-a56f-a06ba010965b"
version = "0.0.7"

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

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
version = "1.11.0"

[[deps.LogExpFunctions]]
deps = ["DocStringExtensions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "13ca9e2586b89836fd20cccf56e57e2b9ae7f38f"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.29"

    [deps.LogExpFunctions.extensions]
    LogExpFunctionsChainRulesCoreExt = "ChainRulesCore"
    LogExpFunctionsChangesOfVariablesExt = "ChangesOfVariables"
    LogExpFunctionsInverseFunctionsExt = "InverseFunctions"

    [deps.LogExpFunctions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    ChangesOfVariables = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"

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

[[deps.MKL_jll]]
deps = ["Artifacts", "IntelOpenMP_jll", "JLLWrappers", "LazyArtifacts", "Libdl", "oneTBB_jll"]
git-tree-sha1 = "5de60bc6cb3899cd318d80d627560fae2e2d99ae"
uuid = "856f044c-d86e-5d09-b602-aeab76dc8ba7"
version = "2025.0.1+1"

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

[[deps.MathOptInterface]]
deps = ["BenchmarkTools", "CodecBzip2", "CodecZlib", "DataStructures", "ForwardDiff", "JSON3", "LinearAlgebra", "MutableArithmetics", "NaNMath", "OrderedCollections", "PrecompileTools", "Printf", "SparseArrays", "SpecialFunctions", "Test", "Unicode"]
git-tree-sha1 = "f5f67affb675630421d169ffd5dfa00cffcc07ca"
uuid = "b8f27783-ece8-5eb3-8dc8-9495eed66fee"
version = "1.35.2"

[[deps.MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "MozillaCACerts_jll", "NetworkOptions", "Random", "Sockets"]
git-tree-sha1 = "c067a280ddc25f196b5e7df3877c6b226d390aaf"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.1.9"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.6+0"

[[deps.MicroCollections]]
deps = ["Accessors", "BangBang", "InitialValues"]
git-tree-sha1 = "44d32db644e84c75dab479f1bc15ee76a1a3618f"
uuid = "128add7d-3638-4c79-886c-908ea0c25c34"
version = "0.2.0"

[[deps.MicroMamba]]
deps = ["Pkg", "Scratch", "micromamba_jll"]
git-tree-sha1 = "011cab361eae7bcd7d278f0a7a00ff9c69000c51"
uuid = "0b3b1443-0f03-428d-bdfb-f27f9c1191ea"
version = "0.1.14"

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

[[deps.MutableArithmetics]]
deps = ["LinearAlgebra", "SparseArrays", "Test"]
git-tree-sha1 = "9c0bc309df575c85422232eedfb74d5a9c155401"
uuid = "d8a4904e-b15c-11e9-3269-09a3773c0cb0"
version = "1.6.3"

[[deps.NaNMath]]
deps = ["OpenLibm_jll"]
git-tree-sha1 = "cc0a5deefdb12ab3a096f00a6d42133af4560d71"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "1.1.2"

[[deps.NamedDims]]
deps = ["AbstractFFTs", "ChainRulesCore", "CovarianceEstimation", "LinearAlgebra", "Pkg", "Requires", "Statistics"]
git-tree-sha1 = "cb8ebcee2b4e07b72befb9def593baef8aa12f07"
uuid = "356022a1-0364-5f58-8944-0da4b18d706f"
version = "0.2.50"

[[deps.NearestNeighbors]]
deps = ["Distances", "StaticArrays"]
git-tree-sha1 = "8a3271d8309285f4db73b4f662b1b290c715e85e"
uuid = "b8a86587-4115-5ab1-83bc-aa920d37bbce"
version = "0.4.21"

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

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"
version = "0.8.5+0"

[[deps.OpenSSL]]
deps = ["BitFlags", "Dates", "MozillaCACerts_jll", "OpenSSL_jll", "Sockets"]
git-tree-sha1 = "38cb508d080d21dc1128f7fb04f20387ed4c0af4"
uuid = "4d8831e6-92b7-49fb-bdf8-b643e874388c"
version = "1.4.3"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "7493f61f55a6cce7325f197443aa80d32554ba10"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "3.0.15+3"

[[deps.OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1346c9208249809840c91b26703912dff463d335"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.6+0"

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

[[deps.Photometry]]
deps = ["ImageFiltering", "ImageTransformations", "Interpolations", "LazySets", "NearestNeighbors", "Parameters", "RecipesBase", "Reexport", "Rotations", "StaticArrays", "Statistics", "StatsBase", "Transducers", "TypedTables"]
git-tree-sha1 = "c0de60f4eaea165a909f64f1e487981eab9adda9"
uuid = "af68cb61-81ac-52ed-8703-edc140936be4"
version = "0.9.3"

[[deps.Pidfile]]
deps = ["FileWatching", "Test"]
git-tree-sha1 = "2d8aaf8ee10df53d0dfb9b8ee44ae7c04ced2b03"
uuid = "fa939f87-e72e-5be4-a000-7fc836dbe307"
version = "1.3.0"

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
deps = ["AbstractPlutoDingetjes", "BaseDirs", "Colors", "Dates", "Downloads", "HypertextLiteral", "InteractiveUtils", "LaTeXStrings", "Markdown", "Pkg", "PlotlyBase", "Reexport", "TOML"]
git-tree-sha1 = "1ae939782a5ce9a004484eab5416411c7190d3ce"
uuid = "8e989ff0-3d88-8e9f-f020-2b208a939ff0"
version = "0.4.6"

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

[[deps.Profile]]
uuid = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"
version = "1.11.0"

[[deps.ProgressMeter]]
deps = ["Distributed", "Printf"]
git-tree-sha1 = "8f6bc219586aef8baf0ff9a5fe16ee9c70cb65e4"
uuid = "92933f4c-e287-5a05-a399-4b506db050ca"
version = "1.10.2"

[[deps.PythonCall]]
deps = ["CondaPkg", "Dates", "Libdl", "MacroTools", "Markdown", "Pkg", "Requires", "Serialization", "Tables", "UnsafePointers"]
git-tree-sha1 = "feab249add2d40873acbd6b286b450bd30b083dd"
uuid = "6099a3de-0909-46bc-b1f4-468b9a2dfc0d"
version = "0.9.24"

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

[[deps.ReachabilityBase]]
deps = ["ExprTools", "InteractiveUtils", "LinearAlgebra", "Random", "Requires", "SparseArrays"]
git-tree-sha1 = "d28da1989cc21fcf57611f928061de5e8f27dc5c"
uuid = "379f33d0-9447-4353-bd03-d664070e549f"
version = "0.3.3"

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

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "838a3a4188e2ded87a4f9f184b4b0d78a1e91cb7"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.0"

[[deps.ResumableFunctions]]
deps = ["Logging", "MacroTools"]
git-tree-sha1 = "910fb2b8f0dd33649f606266c392f639bb939b10"
uuid = "c5292f4c-5179-55e1-98c5-05642aab7184"
version = "0.6.10"

[[deps.Rotations]]
deps = ["LinearAlgebra", "Quaternions", "Random", "StaticArrays"]
git-tree-sha1 = "5680a9276685d392c87407df00d57c9924d9f11e"
uuid = "6038ab10-8711-5258-84ad-4b1120ba62dc"
version = "1.7.1"
weakdeps = ["RecipesBase"]

    [deps.Rotations.extensions]
    RotationsRecipesBaseExt = "RecipesBase"

[[deps.RoundingEmulator]]
git-tree-sha1 = "40b9edad2e5287e05bd413a38f61a8ff55b9557b"
uuid = "5eaf0fd0-dfba-4ccb-bf02-d820a40db705"
version = "0.2.1"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.SIMD]]
deps = ["PrecompileTools"]
git-tree-sha1 = "fea870727142270bdf7624ad675901a1ee3b4c87"
uuid = "fdea26ae-647d-5447-a871-4b548cad5224"
version = "3.7.1"

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

[[deps.SetRounding]]
git-tree-sha1 = "d7a25e439d07a17b7cdf97eecee504c50fedf5f6"
uuid = "3cc68bcd-71a2-5612-b932-767ffbe40ab0"
version = "0.2.1"

[[deps.Setfield]]
deps = ["ConstructionBase", "Future", "MacroTools", "StaticArraysCore"]
git-tree-sha1 = "e2cc6d8c88613c05e1defb55170bf5ff211fbeac"
uuid = "efcf1570-3423-57d1-acb7-fd33fddbac46"
version = "1.1.1"

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

[[deps.SpecialFunctions]]
deps = ["IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "64cca0c26b4f31ba18f13f6c12af7c85f478cfde"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.5.0"
weakdeps = ["ChainRulesCore"]

    [deps.SpecialFunctions.extensions]
    SpecialFunctionsChainRulesCoreExt = "ChainRulesCore"

[[deps.SplitApplyCombine]]
deps = ["Dictionaries", "Indexing"]
git-tree-sha1 = "c06d695d51cfb2187e6848e98d6252df9101c588"
uuid = "03a91e81-4c3e-53e1-a0a4-9c0c8f19dd66"
version = "1.2.3"

[[deps.SplittablesBase]]
deps = ["Setfield", "Test"]
git-tree-sha1 = "e08a62abc517eb79667d0a29dc08a3b589516bb5"
uuid = "171d559e-b47b-412a-8079-5efa626c420e"
version = "0.1.15"

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

[[deps.Static]]
deps = ["CommonWorldInvalidations", "IfElse", "PrecompileTools"]
git-tree-sha1 = "87d51a3ee9a4b0d2fe054bdd3fc2436258db2603"
uuid = "aedffcd0-7271-4cad-89d0-dc628f76c6d3"
version = "1.1.1"

[[deps.StaticArrayInterface]]
deps = ["ArrayInterface", "Compat", "IfElse", "LinearAlgebra", "PrecompileTools", "Static"]
git-tree-sha1 = "96381d50f1ce85f2663584c8e886a6ca97e60554"
uuid = "0d7ed370-da01-4f52-bd93-41d350b8b718"
version = "1.8.0"
weakdeps = ["OffsetArrays", "StaticArrays"]

    [deps.StaticArrayInterface.extensions]
    StaticArrayInterfaceOffsetArraysExt = "OffsetArrays"
    StaticArrayInterfaceStaticArraysExt = "StaticArrays"

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

[[deps.StatsAPI]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1ff449ad350c9c4cbc756624d6f8a8c3ef56d3ed"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.7.0"

[[deps.StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "d1bf48bfcc554a3761a133fe3a9bb01488e06916"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.33.21"

[[deps.StringManipulation]]
deps = ["PrecompileTools"]
git-tree-sha1 = "a6b1675a536c5ad1a60e5a5153e1fee12eb146e3"
uuid = "892a3eda-7b42-436c-8928-eab12a02cf0e"
version = "0.4.0"

[[deps.StructTypes]]
deps = ["Dates", "UUIDs"]
git-tree-sha1 = "159331b30e94d7b11379037feeb9b690950cace8"
uuid = "856f2bd8-1eba-4b0a-8007-ebc267875bd4"
version = "1.11.0"

[[deps.StyledStrings]]
uuid = "f489334b-da3d-4c2e-b8f0-e476e12c162b"
version = "1.11.0"

[[deps.SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "7.7.0+0"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.TSVD]]
deps = ["Adapt", "LinearAlgebra"]
git-tree-sha1 = "c39caef6bae501e5607a6caf68dd9ac6e8addbcb"
uuid = "9449cd9e-2762-5aa3-a617-5413e99d722e"
version = "0.4.4"

[[deps.TableMetadataTools]]
deps = ["DataAPI", "Dates", "TOML", "Tables", "Unitful"]
git-tree-sha1 = "c0405d3f8189bb9a9755e429c6ea2138fca7e31f"
uuid = "9ce81f87-eacc-4366-bf80-b621a3098ee2"
version = "0.1.0"

[[deps.TableScraper]]
deps = ["Cascadia", "Gumbo", "HTTP", "Tables"]
git-tree-sha1 = "73e600bad3a9b6c04c8a055e316fd60dd2ab372c"
uuid = "3d876f86-fca9-45cb-9864-7207416dc431"
version = "0.1.4"

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

[[deps.TiffImages]]
deps = ["ColorTypes", "DataStructures", "DocStringExtensions", "FileIO", "FixedPointNumbers", "IndirectArrays", "Inflate", "Mmap", "OffsetArrays", "PkgVersion", "ProgressMeter", "SIMD", "UUIDs"]
git-tree-sha1 = "38f139cc4abf345dd4f22286ec000728d5e8e097"
uuid = "731e570b-9d59-4bfa-96dc-6df516fadf69"
version = "0.10.2"

[[deps.TiledIteration]]
deps = ["OffsetArrays", "StaticArrayInterface"]
git-tree-sha1 = "1176cc31e867217b06928e2f140c90bd1bc88283"
uuid = "06e1c1a7-607b-532d-9fad-de7d9aa2abac"
version = "0.5.0"

[[deps.TranscodingStreams]]
git-tree-sha1 = "0c45878dcfdcfa8480052b6ab162cdd138781742"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.11.3"

[[deps.Transducers]]
deps = ["Accessors", "ArgCheck", "BangBang", "Baselet", "CompositionsBase", "ConstructionBase", "DefineSingletons", "Distributed", "InitialValues", "Logging", "Markdown", "MicroCollections", "Requires", "SplittablesBase", "Tables"]
git-tree-sha1 = "7deeab4ff96b85c5f72c824cae53a1398da3d1cb"
uuid = "28d57a85-8fef-5791-bfe6-a80928e7c999"
version = "0.4.84"

    [deps.Transducers.extensions]
    TransducersAdaptExt = "Adapt"
    TransducersBlockArraysExt = "BlockArrays"
    TransducersDataFramesExt = "DataFrames"
    TransducersLazyArraysExt = "LazyArrays"
    TransducersOnlineStatsBaseExt = "OnlineStatsBase"
    TransducersReferenceablesExt = "Referenceables"

    [deps.Transducers.weakdeps]
    Adapt = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
    BlockArrays = "8e7c35d0-a365-5155-bbbb-fb81a777f24e"
    DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
    LazyArrays = "5078a376-72f3-5289-bfd5-ec5146d43c02"
    OnlineStatsBase = "925886fa-5bf2-5e8e-b522-a9147a512338"
    Referenceables = "42d2dcc6-99eb-4e98-b66c-637b7d73030e"

[[deps.Tricks]]
git-tree-sha1 = "6cae795a5a9313bbb4f60683f7263318fc7d1505"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.10"

[[deps.TypedTables]]
deps = ["Adapt", "Dictionaries", "Indexing", "SplitApplyCombine", "Tables", "Unicode"]
git-tree-sha1 = "84fd7dadde577e01eb4323b7e7b9cb51c62c60d4"
uuid = "9d95f2ec-7b3d-5a63-8d20-e2491e220bb9"
version = "1.4.6"

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
git-tree-sha1 = "dd260903fdabea27d9b6021689b3cd5401a57748"
uuid = "1986cc42-f94f-5a68-af5c-568840ba703d"
version = "1.20.0"
weakdeps = ["ConstructionBase", "InverseFunctions"]

    [deps.Unitful.extensions]
    ConstructionBaseUnitfulExt = "ConstructionBase"
    InverseFunctionsUnitfulExt = "InverseFunctions"

[[deps.UnsafePointers]]
git-tree-sha1 = "c81331b3b2e60a982be57c046ec91f599ede674a"
uuid = "e17b2a0c-0bdf-430a-bd0c-3a23cae4ff39"
version = "1.0.0"

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

[[deps.WoodburyMatrices]]
deps = ["LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "c1a7aa6219628fcd757dede0ca95e245c5cd9511"
uuid = "efce3f68-66dc-5838-9240-27a6d6f5f9b6"
version = "1.0.0"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+1"

[[deps.ZygoteRules]]
deps = ["ChainRulesCore", "MacroTools"]
git-tree-sha1 = "434b3de333c75fc446aa0d19fc394edafd07ab08"
uuid = "700de1a5-db45-46bc-99cf-38207098b444"
version = "0.2.7"

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

[[deps.micromamba_jll]]
deps = ["Artifacts", "JLLWrappers", "LazyArtifacts", "Libdl"]
git-tree-sha1 = "b4a5a3943078f9fd11ae0b5ab1bdbf7718617945"
uuid = "f8abcde7-e9b7-5caa-b8af-a437887ae8e4"
version = "1.5.8+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.59.0+0"

[[deps.oneTBB_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "7d0ea0f4895ef2f5cb83645fa689e52cb55cf493"
uuid = "1317d2d5-d96f-522e-a858-c73665f53c3e"
version = "2021.12.0+0"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+2"
"""

# ╔═╡ Cell order:
# ╟─3d8a4c43-1a17-4a36-84e8-47a98493ca99
# ╟─14e0627f-ada1-4689-9bc6-c877b81aa582
# ╟─f0678404-72db-4bfd-9a44-ef0b66f3a64f
# ╟─49e1559e-bb19-4e8e-a9a9-67cb2c2d6931
# ╟─84d9ed94-11cb-4272-8bd3-d420c50f990d
# ╟─aa005b55-626e-41e0-8fe1-137bd7dd5599
# ╟─4266575e-e19f-48e4-8b21-6f296c6d3f33
# ╟─aaaaa4d6-737b-4e53-a3a4-fcac09789d4e
# ╟─c1bbb6a2-6996-4fee-a642-a0212b473474
# ╟─abb9a9c8-5cac-4af3-b0a0-b7a3608dfe1a
# ╟─b360ad74-58b7-47b5-a8b0-437ef1119303
# ╠═7c078085-ff30-400d-a0ab-2680f468c415
# ╠═1356c02f-9ff2-491f-b55d-666ee76e6fae
# ╟─06d26240-81b6-401b-8eda-eab3a9a0fb20
# ╠═335a1a12-379a-4e0d-a3de-788369ae3818
# ╟─a04886d9-471a-40ec-9f0b-65ffe89932cf
# ╠═8a78029c-ddf5-4ada-b6d3-a9a649bdbae8
# ╟─cdf14fe8-6b27-44eb-b789-6cf072f4d184
# ╟─a38466b5-c7fb-4600-904b-b7ddd7afd272
# ╠═2b8c75f6-c148-4c70-be6a-c1a4b95d5849
# ╠═dbe812e2-a795-4caa-842d-07da5eabcade
# ╟─9d2b2434-7bd9-42c4-b986-34969101b285
# ╟─74197e45-3b80-44ad-b940-f2544f2f9b54
# ╟─a6de852c-01e6-49a2-bc78-8d1b6eb51c0c
# ╠═7d7cd508-be27-4f52-bc13-91c702450167
# ╟─5abbcbe0-3ee6-4658-9c99-e4567a23e3f6
# ╠═f6197e8e-3132-4ab5-86d7-32572e337c58
# ╟─b7d3fb2b-c113-413c-b340-9dfb0a9b78af
# ╟─2b32512b-63df-4a48-8e72-bf20aa75a845
# ╠═035fcecb-f998-4644-9650-6aeaced3e41f
# ╟─a1cb55ef-a33c-4506-bea4-aa6124026b75
# ╟─6773c197-941e-4de0-b017-ec036fb851bb
# ╟─5cc14d4f-d156-420c-a404-90c541217d83
# ╠═916b8558-b49c-40b6-b9d3-9915d4fe75f0
# ╠═f1ed6484-8f6a-4fbf-9a3d-0fe20360ab3b
# ╠═954c7918-7dd1-4967-a67b-7856f00dc498
# ╠═59fd63bd-5df1-4a45-8505-f2b8c740e488
# ╠═2e59cc0d-e477-4826-b8b6-d2d68c8592a9
# ╟─c06e64ef-4085-4bb5-9b8b-2ed244d5dbe8
# ╟─86e53a41-ab0d-4d9f-8a80-855949847ba2
# ╟─7d54fd96-b268-4964-929c-d62c7d89b4b2
# ╟─1df329a0-629a-4527-8e5d-1dbac9ed8497
# ╠═1fe59945-8bce-44f3-b548-9646c2ce6bda
# ╟─d6bba196-213e-4c90-8d8e-f2ffc8108da6
# ╟─e7ad4e24-5dc9-4713-836a-be001304e45c
# ╟─73e16c0e-873c-46a3-a0fd-d7ed5405ed7b
# ╟─f3683998-543c-4bc4-8b73-fc1de6a6a955
# ╟─102ce649-e560-470e-afa5-699db577e148
# ╟─3d77a38f-1e2f-40a7-bfec-90acf382f042
# ╠═b944bc98-ff4b-4851-89ea-1ee4e3191759
# ╟─36db58d8-23be-461a-ac75-998c8ad43068
# ╟─03d38a82-4c31-4f3a-9afe-d1caead5e8af
# ╟─bdc24b15-d14a-422c-a7aa-5335547fa53c
# ╟─d6d19588-9fa5-4b3e-987a-082345357fe7
# ╠═381d0147-264b-46f6-82ab-8c840c50c7d1
# ╠═79c924a7-f915-483d-aee6-94e749d3b004
# ╟─0d07e670-4ddb-41ce-ac2c-60991a52ded4
# ╠═96dc5bbe-3284-43a0-8c04-c1bb51ad618b
# ╠═635efbd3-bed2-4236-9eb2-c816a713990b
# ╟─15ad7461-9c40-4755-8f00-14aa3be53e0f
# ╟─6470b357-4dc6-4b2b-9760-93d64bab13e9
# ╟─17eb5723-71f4-4344-b1b1-41b894e7582b
# ╟─59392770-f59e-4188-a675-89c2f2fc67d9
# ╟─e34ceb7c-1584-41ce-a5b5-3532fac3c03d
# ╟─276ff16f-95f1-44eb-971d-db65e8821e59
# ╟─934b1888-0e5c-4dcb-a637-5c2f813161d4
# ╟─c5286692-2610-414d-97b7-ffab0bd485a7
# ╟─4a6a8956-f6e5-433a-a87b-056a5123ffbc
# ╟─502fe5dd-d55a-450e-9209-60dc05f395dc
# ╟─14998fe7-8e22-4cd4-87c6-9a5334d218ed
# ╟─4a779bd1-bcf3-41e1-af23-ed00d29db46f
# ╟─7f9c4c42-26fc-4d02-805f-97732032b272
# ╟─e927297b-9d63-4448-8245-4d73d1fbff27
# ╠═399f53c5-b654-4330-9ead-4d795917b03b
# ╟─c5e95837-fd89-4da2-b480-13f5ed788fb6
# ╠═edda8d09-ec46-4a0b-b1b2-b1289ee5456e
# ╟─29197489-441c-440d-9ce2-3dbd17fa53fc
# ╠═f2c89a20-09d5-47f4-8f83-e59477723d95
# ╟─a00cbbfc-56ce-413a-a7b8-13de8541fa6f
# ╠═4042bc32-1a14-4408-974d-7405fd8c8ccc
# ╟─95f9803a-86df-4517-adc8-0bcbb0ff6fbc
# ╟─a5f3915c-6eed-480d-9aed-8fdd052a324a
# ╟─31c23e2b-1a2d-41aa-81c1-22868e241f7e
# ╟─6cec1700-f2de-4e80-b26d-b23b5f7f1823
# ╟─8a39fbbb-6b5b-4744-a875-469c289242fb
# ╟─3f548bb1-37b0-48b7-a35c-d7701405a64e
# ╟─fd7a53d1-2c6d-4d6a-b546-5c766c9a39d7
# ╟─46e6bba9-0c83-47b7-be17-f41301efa18e
# ╟─77544f9e-6053-4ed6-aa9a-4e7a54ca41d9
# ╟─3242f19a-83f7-4db6-b2ea-6ca3403e1039
# ╟─1e5596fb-7dca-408b-afbd-6ca2e2487d75
# ╟─2ea12676-7b5e-444e-8025-5bf9c05d0e2d
# ╟─d359625e-5a95-49aa-86e4-bc65299dd92a
# ╟─829cde81-be03-4a9f-a853-28f84923d493
# ╟─1d2bedb1-509d-4956-8e5a-ad1c0f1ffe26
# ╟─9c482134-6336-4e72-9d30-87080ebae671
# ╟─90b6ef16-7853-46e1-bbd6-cd1a904c442a
# ╟─f290d98e-5a8a-44f2-bee5-b93738abe9af
# ╟─3c601844-3bb9-422c-ab1e-b40f7e7cb0df
# ╟─f26f890b-5924-497c-85a3-eff924d0470b
# ╟─95a67d04-0a32-4e55-ac2f-d004ecc9ca84
# ╟─7d99f9b9-f4ea-4d4b-99b2-608bc491f05c
# ╟─2baf0cba-7ef9-4dd5-bc68-bcdac7753b30
# ╠═ab2bac2b-b2ba-4eaa-8444-439485627bad
# ╠═48f4cdf3-b3d7-4cd6-8071-78292fec0db9
# ╠═285a56b7-bb3e-4929-a853-2fc69c77bdcb
# ╠═a984c96d-273e-4d6d-bab8-896f14a79103
# ╟─21e828e5-00e4-40ce-bff5-60a17439bf44
# ╟─e35d4be7-366d-4ca5-a89a-5de24e4c6677
# ╟─a3bcad72-0e6c-43f8-a08d-777a154190d8
# ╟─8da80446-84d7-44bb-8122-874b4c9514f4
# ╟─24256769-2274-4b78-8445-88ec4536c407
# ╟─5b079ce8-3b28-4fe7-8df2-f576c2c948f5
# ╠═6bc5d30d-2051-4249-9f2a-c4354aa49198
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
