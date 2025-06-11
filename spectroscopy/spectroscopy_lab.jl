### A Pluto.jl notebook ###
# v0.20.10

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

# ╔═╡ e46b678e-0448-4e31-a465-0a82c7380ab8
begin
# Web
using JSON, PlutoUI, CommonMark
using Downloads: download
# using MarkdownLiteral: @mdx

# Visualization
using Images, AstroImages, PlutoPlotly
end

# ╔═╡ bdf98bfb-ad09-4c02-9ef5-c02552b70ad5
md"""
# 🌈 Unistellar Spectroscopy Lab

This notebook provides a short methods introduction to the field of [spectroscopy](https://en.wikipedia.org/wiki/Astronomical_spectroscopy) in astronomy. As a companion to the *[RSpec Unistellar Manual](https://www.rspec-astro.com/download/Unistellar%20Spectra.pdf)*, we will walk through some of the techniques behind the core concepts used there to produce and analyze astronomical spectra. Over the course of the notebook, we will introduce and use interactive tools and hands-on live code examples to investigate the following concepts:

* Image processing
* Array/matrix operations
* Wavelength calibration

Having some familiarity in high-level programming languages like Julia or Python will be useful, but not necessary, for following along with the topics covered above. At the end of this notebook, you will hopefully have the tools to build your own analysis pipelines for processing astronomical spectra, as well as understand the principles behind other astronomical software at a broad level.
"""

# ╔═╡ 1e2dc809-1614-487e-b0fe-f058188555ee
cm"""
With this requisite information out of the way, let's get our hands on some real data!
"""

# ╔═╡ 7e3aedd9-6c94-42ce-aeaa-ea0c2d71a9b1
msg_adding_colors = md"""
#### Adding colors in Julia 🎨
This makes magenta!

```julia
RGB(1, 0, 0) + RGB(0, 0, 1)
```

$(RGB(1, 0, 0) + RGB(0, 0, 1))
""";

# ╔═╡ 127ca8df-46c7-4d02-8f9b-e27983978441
md"""
## Image processing

Astronomical spectra start their lives as a picture. These images can come in a variety of different formats, the most popular being the [Flexible Image Transport System](https://en.wikipedia.org/wiki/FITS) (FITS) format. We will explore this later in the notebook, but let's start with another common format that you probably use everyday, [Portable Network Graphics](https://en.wikipedia.org/wiki/PNG) (PNG), to get an idea of how image data is represented.
"""

# ╔═╡ 30585bee-7751-47ca-bcf8-2b57af2b1394
md"""
### Color images
"""

# ╔═╡ 249dd9ce-239e-45a9-9f59-c8991ecd299f
cm"""
We can use an image of anything, really, so why not start with dogs? Clicking the button below will pull a new dog image from the internet.
"""

# ╔═╡ 848cfcdc-d15e-4f8e-8729-a20bb50327fa
cm"""
!!! warning "Heads up"

	Sometimes a url returned by the [API](https://en.wikipedia.org/wiki/API) leads to a 404 page. Just hit the button again to download a new dog if this happens.
"""

# ╔═╡ 0f3ae63c-cc02-43a8-9560-3770439640a0
@bind run_again Button("Random!")

# ╔═╡ 9f83d261-61c8-4ab2-9e2e-a9a2fe24f3a5
cm"""
*Images courtesy of* <https://dog.ceo/dog-api/>
"""

# ╔═╡ c402e19e-05f6-4b4f-a9dc-f2036e415b17
cm"""
We now have an image that we can analyze. For starters, let's display some key characteristics about this image:
"""

# ╔═╡ 9014873e-5b1b-4605-9dd6-efb9840e5732
cm"""
Even though this part is Julia specific, the underlying information is general enough to apply to most image processing libraries. Let's break down what each piece means: 

* [`ColorTypes`](https://github.com/JuliaGraphics/ColorTypes.jl): The name of the package where a type called `RGB` is defined.

* [`RGB`](https://github.com/JuliaGraphics/ColorTypes.jl#rgb-plus-bgr-xrgb-rgbx-and-rgb24-the-abstractrgb-group): A type that stores the red, green, and blue intensity values of a pixel. These can be thought of as [sub-pixels](https://en.wikipedia.org/wiki/Pixel#Subpixels)

* [`FixedPointNumbers`](https://github.com/JuliaMath/FixedPointNumbers.jl): The name of the package where a type called `N0f8` is defined.

* [`N0f8`](https://github.com/JuliaMath/FixedPointNumbers.jl#type-hierarchy-and-interpretation): A type that represents a number in memory. This essentially defines the specific number type used for each red, green, and blue value in each pixel. More on [`N0f8` and other number formats](https://juliaimages.org/latest/tutorials/quickstart/#The-0-to-1-intensity-scale).
"""

# ╔═╡ 685c8647-3de7-4775-ba71-fdfd23c557de
cm"""
To summarize, our image is just a matrix of pixels, where each pixel value is represented by a triple of RGB values stored in a memory efficient format. Let's explore next how these numbers connect to how we perceive color.
"""

# ╔═╡ 9427d980-2420-4285-992e-099bc6d1aa55
@bind resample Button("Resample")

# ╔═╡ 6880b7a1-0a74-4879-bd85-90c8f8e947d2
cm"""
Below our selected pixel, we map these (R, G, B) values to their corresponding sub-pixel, where 0 represents black (or no brightness), and 1 represents the peak brightness for the given color channel. The resulting color is then the [additive combination](https://en.wikipedia.org/wiki/RGB_color_model#Additive_colors) of these individual subpixels.
"""

# ╔═╡ 736e7f03-7eb9-4805-afe4-74170c046c4c
cm"""
We are now one step closer to building a spectrum of our image. Astronomers typically work with [black and white](https://hubblesite.org/contents/articles/the-meaning-of-light-and-color) (or [grayscale](https://en.wikipedia.org/wiki/Grayscale)) images, so we will next see how we can convert our image to this form using the information we have above. Later, we will see why this is a beneficial form to have our image in when we explore the FITS file format.
"""

# ╔═╡ 9932a3b1-6d52-4ed1-8884-2f90f765ac68
md"""
### Grayscale images
"""

# ╔═╡ 4ea2b324-39dc-4a36-a36b-96eca525e00c
cm"""
The converversion process from ``RGB`` to Grayscale for a given pixel is achieved by taking a weighted average of its channel values according to an [international standard](https://en.wikipedia.org/wiki/Luma_%28video%29#Rec._601_luma_versus_Rec._709_luma_coefficients) established to emulate how the [human eye perceives relative brightnesses](https://en.wikipedia.org/wiki/Grayscale#Converting_color_to_grayscale):

```math
0.299 R + 0.587 G + 0.114 B \quad.
```

This is [already implemented for us](https://juliaimages.org/latest/examples/color_channels/rgb_grayscale/) in the `ColorTypes` package, which we apply below to each pixel of our image to produce the following grayscale version:
"""

# ╔═╡ 703050cd-57fc-4b8b-b631-d5b8124ef872
cm"""
Taking a look at the properties of our new image, we see that now instead of being a matrix composed of `RGB{N0f8}` types, it is composed of `Gray{N0f8}`s.
"""

# ╔═╡ cf940fd1-4f37-477a-ab46-e75902273f5d
cm"""
!!! note
	We omit the package names for brevity.
"""

# ╔═╡ 8c79235d-5b03-4e97-acaf-b3eea88e91b9
cm"""
In other words, instead of three numbers representing each pixel, we now have a single number for each, which we can view directly:
"""

# ╔═╡ a2842f26-520e-42c0-bc4e-b04feccf22b2
cm"""
We are now ready to build our spectrum by working directly with this matrix.
"""

# ╔═╡ 50e3b47b-4072-4be6-b740-efdf3dd9a3a2
cm"""
!!! tip
	For more on image analysis and other modern math/science computation tools, see this fantastic resource from [Computational Thinking](https://computationalthinking.mit.edu/Fall23/images_abstractions/images/).
"""

# ╔═╡ 2f18fb1a-2178-4e12-b411-13fa49f3084f
md"""
## Array/matrix operations
"""

# ╔═╡ 77836abd-a282-471b-a994-395781fc1f0b
cm"""
Now that we are able to access the underlying structure of our data, let's explore next how we can extract subsets that we might be interested in. One common approach, known as [array slicing](https://en.wikipedia.org/wiki/Array_slicing), accomplishes this by selecting the subset of pixels that fall within a specified rectangle.

Try using the sliders below to specify a region of interest where we would like to build a spectrum from. *Note that this will only work in the locally downladed version of this notebook.*
"""

# ╔═╡ 9e16a591-4d89-4d90-a96f-eed8f2078dad
cm"""
Calling the `gray` function again, we have the following array of pixel values to work with:
"""

# ╔═╡ 14f83f54-f51c-4af4-b388-b76f188e7649
cm"""
To build a spectrum of this selection across a given direction, we next perform a summation in the perpendicular direction. Synonymous terms for this are "dimension" and "axis". For example, if we wanted a spectrum in the "horizontal direction", we would sum up all the pixels in a given column. We call this final sum for a given column the intensity.

Many libraries have this operation built in, typically with a `dims` or `axis` keyword to specify the direction to sum in, as shown below:
"""

# ╔═╡ 2f5da861-2a83-4ed1-9b6b-f9081768ca05
cm"""
This returns a vector that should be as long as the number of columns in our original image. Plotting these value as a function of the column location then gives us our 1D spectrum!
"""

# ╔═╡ 7e3e9ccc-5ed8-4067-b944-aac86e3a2cb8
cm"""
!!! tip
	Try moving the original region over different parts of the image to see if any particular features can be picked out in the final spectrum.
"""

# ╔═╡ 7616d2b0-9a2f-467e-91a6-da321717791f
cm"""
Now that we are experts at constructing the spectra of dogs, let's turn next to constructing the spectra of astronomical objects.
"""

# ╔═╡ ee3ee62d-1548-4b13-afac-ea50cdec1ba5
md"""
### eVscope Live View image
"""

# ╔═╡ 715d8d40-3ba1-4244-90e7-f4a5e1d76a1f
cm"""
Following the procedures outlined in the [*RSpec Unistellar Manual*](https://www.rspec-astro.com/download/Unistellar%20Spectra.pdf), here is a brief Live View image of [Castor](https://en.wikipedia.org/wiki/Castor_(star)) that I captured from my backyard.
"""

# ╔═╡ 01ee9b23-caa3-49d6-aff4-972ea7be2d79
cm"""
The zeroth order light appears as the bright white spot passing straight through the grating, and the first order spectrum of light can be seen being dispersed horizontally, with redder light to the right. Similarly to the dog images that we have been working with, this is just a regular PNG file which we can analyze in exactly the same way as earlier to produce our 1D spectrum.

For convenience, we have modified the region of interest selection process so that it can be directly selected by clicking and dragging over the plot below. Note that the colormap used just artificially applies different colors for viewing purposes, but does not change the underlying data.
"""

# ╔═╡ 07d7dd41-8b49-4afc-9da2-b977473b24a3
cm"""
Below are the general steps used to produce the final spectrum:

```julia
# Convert to grayscale
arr_ev_live = ev_live .|> Gray |> channelview

# Get x and y limits from dragged region in plot
xrange_ev_live, yrange_ev_live = get_lims(arr_ev_live, limits_ev_live)

# Use these bounds to select the region of interest from our grayscale image
window_ev_live = @view arr_ev_live[yrange_ev_live, xrange_ev_live]

# Sum across rows for each column
prof_1D_ev_live = sum(window_ev_live; dims=1) |> vec
```
"""

# ╔═╡ d25e3ef6-c9a8-4219-81cd-04202187e347
cm"""
These steps to produce a 1D spectrum are common enough to wrap into a general function so that they can be re-used for other targets.
"""

# ╔═╡ 7e60b93f-b57f-48fe-a196-a36c3d1f8cb6
cm"""
To close out this section on performing array operations on image data, we will look at one of the most common image formats used in astronomy, FITS files.
"""

# ╔═╡ f7dd6681-2792-4753-b016-2c7358a343a9
md"""
### FITS
"""

# ╔═╡ 7d052ff9-f0dd-4ce7-a5c8-5eed191ae467
cm"""
Below is a science image of [HD123657](https://simbad.u-strasbg.fr/simbad/sim-basic?Ident=HD123657&submit=SIMBAD+search) taken courtesy of Unistellar Citizen Scientist, **\@Stephen Haythornthwaite**. For more on taking science images, [see here](https://www.unistellar.com/citizen-science/exoplanets/tutorial/). One of the benefits of taking images in science mode is that it allows our users to [download their raw data](https://help.unistellar.com/hc/en-us/articles/10989728346780-UniData-Access-How-to-Download-Your-RAW-Data-) in FITS format. To open it, we use the [`AstroImages.jl`](https://github.com/JuliaAstro/AstroImages.jl) package which behaves similarly to [`ds9`](https://sites.google.com/cfa.harvard.edu/saoimageds9) and [`astropy`](https://docs.astropy.org/en/stable/io/fits/).
"""

# ╔═╡ a412dd91-f4bd-4d55-933e-3a6d00db4ab0
cm"""
!!! tip

	For more on using science mode observations to analyze eVscope spectra, see this advanced section of the [*RSpec Unistellar Manual*](https://www.rspec-astro.com/download/Unistellar%20Spectra.pdf): "Using Method #3: Science menu’s Exoplanet transit mode with external stacking".
"""

# ╔═╡ 70040896-2bd3-43a1-adfa-2114424e42e7
cm"""
Unlike Live View images, [FITS](https://en.wikipedia.org/wiki/FITS) images are already in grayscale and can come packaged with additional metadata (known as *headers*) and data tables that inform us about the observing conditions (e.g., longitude, latitude, gain, exposure time) that our data were taken in. Together these are known as Headers + Data Units (or [*HDUs*](https://heasarc.gsfc.nasa.gov/docs/heasarc/fits_overview.html)), and they can help us reduce systematics from the instrument and environment. Additionally, individual science images can be stacked together to increase the overall signal-to-noise ratio (SNR) of our observations.
"""

# ╔═╡ 27642020-21e5-4de1-9f67-a951a6a682ed
cm"""
!!! note "But why grayscale?"
	FITS images give us a direct correspondence between the location of the pixel that a particular photon of light falls on in our array, and how strong that signal will be. Images taken at specific wavelengths can then be stacked together to create [full color composite images](https://hubblesite.org/contents/articles/the-meaning-of-light-and-color). The downside for our particular usecase is that these images taken by our eVscope sensor have not been [debayered](https://en.wikipedia.org/wiki/Bayer_filter), which complicates this correspondance. We will explore some of the imaging artifacts that are introduced by this, and potential techniques that we can use to mitigate them.
"""

# ╔═╡ b3dacdf9-f45f-40b8-b463-eac43ceb7e87
cm"""
!!! note "Why do the rows and columns look flipped?"
	Note that the rows and columns appear flipped relative to what is shown in our plot. This is because, like Julia and Fortran, FITS files store their array data in [column-major](https://docs.julialang.org/en/v1/manual/performance-tips/#man-performance-column-major) format in memory. To match the convention that we have adopted for displaying images (origin in top-left corner, x increasing downwards, y increasing rightwards), we use the [`permutedims`](https://docs.julialang.org/en/v1/base/arrays/#Base.permutedims) function to swap the row and column order.

!!! warning "A note on debayering"
	
	We see some immediate qualitative similarities and differences from our dog spectrum. The dips in our 1D spectrum line up with the dimmer regions in the image, just like the "dog" features noted earlier. Zooming in on the image though, we see a cross-hatching pattern emerge. This is an artifact of the Bayer filter used by our sensor, and it manifests as a "sawtooth" pattern in our 1D specrtrum.
	
	As discussed in the "Debayering" section of the *[RSpec Unistellar Manual](https://www.rspec-astro.com/download/Unistellar%20Spectra.pdf)*, this imaging artifact can be reduced by either binning our data beforehand or applying a debayering algorithm as part of a stacking routine when combining our FITS images. For our purposes, the spectrum we have is good enough quality for the low-resolution spectroscopy analysis we are doing. For example, we already can see broad molecular band features that are characteristic of this [M-type](https://en.wikipedia.org/wiki/Stellar_classification#Class_M) star.

!!! tip
	Stay tuned for future labs on comparing different stellar types from eVscope spectral data!
"""

# ╔═╡ 2c163542-8825-491c-8277-6097da40221f
cm"""
Below are similar steps that we used to produce the 1D spectrum of our eV Live View image from earlier. The main difference is that we are now working directly with the numerical image array instead of needing to convert from an RGB or grayscale image first. For more on working with FITS files, [see here](https://juliaastro.org/AstroImages/stable/manual/loading-images/).
"""

# ╔═╡ 25326216-a51b-4e9c-a484-3853ae135a16
cm"""
So far we have just been working with everything in pixel space. To begin analyzing potential [absorption/emission features](https://en.wikipedia.org/wiki/Spectral_line), we will next see how to convert to wavelength space.
"""

# ╔═╡ 2c36115d-c399-404a-80f0-1a8ee3223cb1
md"""
## Wavelength calibration
"""

# ╔═╡ 25002ec9-6c1a-47e8-aebf-64b2c649c0c7
cm"""
In this final process, we will use information about spectral features from a known reference to determine the general relationship between the pixel coordinate ``(\mathrm{px})`` on our sensor, and the wavelength of light falling upon it ``(\lambda)``. One common approach is to assume a linear relationship between these two spaces. In other words:

```math
\lambda - \lambda_0= d \times (\mathrm{px} - \mathrm{px}_0)\ ,
```

where ``(d)`` is the dispersion in wavelength per pixel and ``(\mathrm{px}_0)`` is the pixel coordinate corresponding to where we would like the wavelength ``(\lambda_0)`` to be zero (this allows us to have a relation of the form ``λ = \dots``). Using the location of the zeroth order light is typically a good choice for this. To determine ``d`` we select one other feature in our reference spectrum with known wavelength.

For example, let's use our image of Castor from earlier since it (well, technically the three brightest stars in this sextuple system that all resolve into a single point) is an A-type star. These types of stars are wonderful calibration sources because they tend to have prominent [Balmer series](https://en.wikipedia.org/wiki/Balmer_series) lines from hydrogen absorption in their atmopsheres. Identifying the (pixel, wavelength) pair ``(\mathrm{px}_\mathrm{line}, \lambda_\mathrm{line})``, we have:

```math
\newcommand{\wavline}{\lambda_\mathrm{line}}
\newcommand{\pxline}{\mathrm{px}_\mathrm{line}}
\newcommand{\pxzero}{\mathrm{px}_0}

\begin{align*}
d &= \frac{\wavline - 0.0}{\pxline - \pxzero} = \frac{\wavline}{\pxline - \pxzero} \\
\lambda &= \boxed{d \times (\mathrm{px} - \pxzero)}\ ,
\end{align*}
```
"""

# ╔═╡ 307c7c22-5dbf-4134-beaf-815bcfeb2e65
cm"""
Try to identify the zero-point and H-β line and record their column pixel coordinates in the fields below. The H-β will typically be the deepest absorption feature in the A-type spectrum. To see how we did, select the `Show lines` option to overlay the rest of the Balmer series lines. They should coincide with the other absorption features present in our spectrum.
"""

# ╔═╡ e3cc6aff-b777-4391-97b2-f24f288127c5
cm"""
$(@bind show_lines CheckBox()) **Show lines**
"""

# ╔═╡ bdb84f9c-4eef-494d-8d8f-d70fe35286ac
md"""
# Notebook setup 🔧
"""

# ╔═╡ 46deb312-8f07-4b4e-a5b4-b852fb1d016d
TableOfContents()

# ╔═╡ 5b638405-5f75-473c-9de9-6acac9856608
md"""
## Convenience functions
"""

# ╔═╡ 4c6a8538-2124-44f0-9891-4a3e1472ea4e
function img_info(img)
	nrows, ncols = size(img)
	eltype_img = eltype(img)
	@debug "Image info" nrows ncols eltype_img
	return nrows, ncols, eltype_img
end

# ╔═╡ e1ae334d-548b-4259-af7c-e13b773f7b3e
msg(x) = details("Details", x)

# ╔═╡ 0968d0d2-7a53-47c5-be13-9c941c0fba0b
cm"""
!!! note "Using this notebook"
	Some parts of this [Pluto notebook](https://plutojl.org/) are partially interactive online, but for full interactive control, it is recommended to download and run this notebook locally. For instructions on how to do this, click the `Edit or run this notebook` button in the top right corner of the page, or [click on this direct link](https://computationalthinking.mit.edu/Fall24/installation/) which includes a video and written instructions for getting started with Julia and Pluto 🌱.

	!!! tip "First time running"
		**Note**: This notebook will download all of the analysis packages and data needed for us, so the first time it runs may take a little while (~ a few minutes depending on your internet connection and platform). Clicking on the `Status` tab in the bottom right will bring up a progress window that we can use to monitor this process, and it also includes an option at the bottom marked `Notify when done` that can be selected to give us a notification pop-up in our browser when everything is finished.

	This is a fully hackable notebook, so exploring the [source code](https://github.com/icweaver/UCAN/blob/main/spectroscopy/spectroscopy_lab.jl) and making your own modifications is encouraged! Unlike Jupyter notebooks, Pluto notebook are just plain Julia files. Any changes you make in the notebook are automatically saved to the source file.

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

	In the local version of this notebook, an "eye" icon will appear at the top left of each cell on hover to reveal the underlying code behind it and a `Live Docs` button will also be available in the bottom right of the page to pull up documentation for any function that is currently selected. In both local and online versions of this notebook, user defined functions and variables are also underlined, and (ctrl) clicking on them will jump to where they are defined.
"""

# ╔═╡ bed3c1a0-aa13-4c61-a074-9b38f9a4d306
cm"""
!!! note "Web aside"
	The website we are pulling images from provides an [API](https://en.wikipedia.org/wiki/API) to interact with its data. We use the stdlib [`Downloads.jl`](https://github.com/JuliaLang/Downloads.jl) to call this API, [`JSON.jl`](https://github.com/JuliaIO/JSON.jl) to parse the data that we downloaded, and [`Images.jl`](https://github.com/JuliaImages/Images.jl) to load it into Julia. This is essentially the same as doing the following on a local PNG file:
	```julia
	using Images
	img = load(LOCAL PATH TO MY FILE)
	```

	In this case, the path is just the url of the hosted image online provided by the API.
""" |> msg

# ╔═╡ 248c07d3-48ee-40a1-b9b5-d57f49b56d6f
cm"""
!!! note
	By default, the value of a variable is displayed above the cell, and debugging/logging information below. Adding a semicolon to the end of the line will suppress the former being displayed in the notebook if we like.
""" |> msg

# ╔═╡ cf371199-c283-46e8-8174-31796e2224cb
cm"""
!!! note
	Julia has a delightful way of applying a function element-wise to its inputs, known as [dot syntax](https://docs.julialang.org/en/v1/manual/functions/#man-vectorized).
""" |> msg

# ╔═╡ f7f490fe-32d5-4a00-a12a-07bfcc1d3edf
md"""
!!! note
	We used the optional [`@view`](https://docs.julialang.org/en/v1/base/arrays/#Base.@view) macro here to access the data directly instead of making a copy. For more on views vs. copies [see here](https://docs.julialang.org/en/v1/base/arrays/#Views-(SubArrays-and-other-view-types)), and for more on macros [see here](https://docs.julialang.org/en/v1/manual/metaprogramming/#man-macros).
""" |> msg

# ╔═╡ c37fc603-8943-4be6-9c73-1f327e8b7885
cm"""
!!! note "Why vec?"
	Array operations in Julia preserve dimensionality to make things [more consistent and composable](https://stackoverflow.com/a/42353230/16402912). For example,

	```julia
	sum([
		1 2
		3 4
	]; dims=1)
	```

	returns another matrix

	```julia
	1×2 Matrix{Int64}:
	 4  6
	```

	instead of silently changing the shape out from under us to a 1D vector

	```julia
	[4, 6]
	```

	The flipside is that the [plotting library we are using](https://plotly.com/) expects a simple vector, so we call [`vec`](https://docs.julialang.org/en/v1/base/arrays/#Base.vec) on the original sum to make this transformation for us before passing it to Plotly.

!!! note "What does |> do?"
	Known as the [pipe operator](https://docs.julialang.org/en/v1/manual/functions/#Function-composition-and-piping), this is a convenient way to pass the output of one function as input to another. For example,

	```julia
	sqrt(sum([1, 4, 5, 6])) # 4.0
	```

	is equivalent to:

	```julia
	[1, 4, 5, 6] |> sum |> sqrt # 4.0
	```
""" |> msg

# ╔═╡ 1cef03ec-1991-4491-a415-c711ea457e05
cm"""
!!! note "Plotly commands"
	```julia
	p = make_subplots(;
		rows = 2,
		shared_xaxes = true,
		vertical_spacing = 0.02,
		x_title = "pixel column",
	)
	
	add_trace!(p, scatter(; x=col_range_dog, y=prof_1D_dog_vals); row=1)
	
	add_trace!(p, heatmap(
		x = col_range_dog,
		y = reverse(row_range_dog),
		z = window_dog_vals,
		colorscale = :Greys,
		showscale = false,
	) ; row=2)
	
	update!(p;
		layout = Layout(
			yaxis = attr(title="intensity"),
			yaxis2 = attr(scaleanchor=:x, title="pixel row")
		)
	)
	```
""" |> msg

# ╔═╡ 27ad53e4-40c6-4d2e-a87b-d766f048c4bd
cm"""
!!! note "What is channelview?"

	This is a more general version of `gray` that also works for color images and returns a view instead of a copy. Either function can be used. For more information, [see here](https://juliaimages.org/v0.20/conversions_views/#Color-separations:-views-for-converting-between-numbers-and-colors-1).
""" |> msg

# ╔═╡ 75108863-4a62-4751-aeee-246250fbf8b8
function get_lims(arr, limits)
	ymax, xmax = size(arr)
	xlims = limits["xaxis"] .|> (x -> round(Int, x))
	xlo, xhi = xlims
	xlo = max(1, xlo)
	xhi = min(xhi, xmax)
	
	ylims = limits["yaxis"] .|> (x -> round(Int, x))
	yhi, ylo = ylims # Assuming heatmap y-axis reversed
	ylo = max(1, ylo)
	yhi = min(yhi, ymax)

	# @debug :vals xlo xhi ylo yhi

	return xlo:xhi, ylo:yhi
end

# ╔═╡ b4f43581-09e8-45f8-bdc1-766dd88bdfc3
"""
	compute_spec1D(arr, region_lims)

Given a rectangular region specified by `region_lims` inside a 2D image array `arr`, return its 1D spectrum computed along the horizontal axis. Also return the horizontal range of the region for convenience when plotting the 1D spectrum with its corresponding image array.
"""
function compute_spec1D(arr, region_lims)
	xrange, yrange = get_lims(arr, region_lims)
	region = @view arr[yrange, xrange]
	return vec(sum(region; dims=1)), xrange
end

# ╔═╡ 7d1caf58-d1db-4fcb-a62b-5c2a16b56732
stake! = String ∘ take!

# ╔═╡ 0b7dff7d-26d2-4c00-8d39-dceabb7433b6
begin
	run_again
	
	img_dog = let
		url = "https://dog.ceo/api/breeds/image/random"
		# Dogs like stake
		payload = download(url, IOBuffer()) |> stake!
		url = JSON.parse(payload)["message"]
		load(download(url))
	end
end

# ╔═╡ f102cbeb-edde-4814-94cb-0f8a8b73f836
nrows_dog, ncols_dog, eltype_dog = img_info(img_dog)

# ╔═╡ 64a3d702-d229-4fd1-bd75-f351a4ee1172
cm"""
We see here that our image is $(nrows_dog) rows by $(ncols_dog) columns wide, and each cell (or pixel) of this image is represented by:
"""

# ╔═╡ 256f479b-7c90-4ad4-a893-e3e5c2266516
@debug eltype_dog

# ╔═╡ 0d260f11-abcd-404d-885a-ba02f2692e36
begin
	N_sampled_pixels = 5
	resample
	sample_px_dog = rand(img_dog, N_sampled_pixels)
end

# ╔═╡ cd2e384e-6f30-40b9-86f9-9a285a956b94
cm"""
We have $(N_sampled_pixels) pixels above sampled from our image. Based on how colorful and varied the image is, these pixels can have a range of different colors between them. Pull the slider to look at each of these pixels one by one and/or click the `Resample` button to select $(N_sampled_pixels) new pixels at random. For convenience, we also display the individual (R, G, B) values next to our slider.
"""

# ╔═╡ 9193e583-fe34-4a62-8142-5981e2335276
@bind px_dog Slider(sample_px_dog; show_value=true)

# ╔═╡ 5dc94909-7181-42be-a252-4fcfb6a84ff0
let
	r, g, b = px_dog .|> (red, green, blue)
	
	md"""
	**Selected pixel:** $(px_dog)
	
	``\Longrightarrow`` R $(RGB(r, 0, 0)), G $(RGB(0, g, 0)), B $(RGB(0, 0, b))
	"""
end

# ╔═╡ 9edd83bf-bcae-4f39-940d-4265bdcd2c34
gray_dog = Gray.(img_dog)

# ╔═╡ d39b4688-a25e-4e47-9037-eeb7e3a6918c
img_info(gray_dog);

# ╔═╡ c77bb96f-357e-4676-a504-ff93a5cd1711
gray.(gray_dog)

# ╔═╡ f5dfab17-a789-46dd-ae4f-d3707d0a4573
cm"""
`rows:` $(@bind row_range_dog RangeSlider(1:size(gray_dog, 1); default=1:1))
`columns`: $(@bind col_range_dog RangeSlider(1:size(gray_dog, 2); default=1:1))
"""

# ╔═╡ bb008a9b-8538-418d-9e70-50d9983c2074
let
	tmp = copy(gray_dog)
	tmp[row_range_dog, col_range_dog] .= RGB(0, 0, 0)
	tmp
end

# ╔═╡ fcc96529-3b20-4a59-9d2d-48612f4c16f3
window_dog = @view gray_dog[row_range_dog, col_range_dog];

# ╔═╡ 096b8d1e-9092-4110-95a7-7cff9210ba43
nrows_window_dog, ncols_window_dog, _ = img_info(window_dog);

# ╔═╡ fedb57fe-574c-4567-933a-052e9b8d50bd
cm"""
Based on our selections, the black rectangular region of interest extends from row $(first(row_range_dog)) to $(last(row_range_dog)), and from column $(first(col_range_dog)) to $(last(col_range_dog)) of our original image, resulting in a slice that is $(nrows_window_dog) rows by $(ncols_window_dog) columns. We selected this range by using the following array syntax:

```julia
array_slice = original_array[row_range, column_range]
```
"""

# ╔═╡ 12c0a504-856d-40b0-aa01-bbb992167943
window_dog_vals = gray.(window_dog)

# ╔═╡ d0203d68-6a55-46ec-ab8f-8fdfc5b1356d
prof_1D_dog_vals = sum(window_dog_vals; dims=1) |> vec

# ╔═╡ d4ca722f-ebc8-411d-a2f1-48fb83373e54
cm"""
!!! warning "Heads up"

	Be aware of potential [arithmetic overflow](https://juliaimages.org/latest/tutorials/arrays_colors/#A-note-on-arithmetic-overflow) when performing operations on your data. In this case, the function `sum` already takes care of this for us by first converting our pixel values to a larger data type.

	```julia
	eltype(prof_1D_dog_vals)
	```

 	--> **$(eltype(prof_1D_dog_vals))**
"""

# ╔═╡ d3b6afc1-c29b-476a-90ed-721796af130f
let
	p = make_subplots(;
		rows = 2,
		shared_xaxes = true,
		vertical_spacing = 0.02,
		x_title = "pixel column",
	)
	add_trace!(p, scatter(; x=col_range_dog, y=prof_1D_dog_vals); row=1)
	add_trace!(p, heatmap(
		x = col_range_dog,
		y = reverse(row_range_dog),
		z = window_dog_vals,
		colorscale = :Greys,
		showscale = false,
	) ; row=2)
	update!(p;
		layout = Layout(
			yaxis = attr(title="intensity"),
			yaxis2 = attr(scaleanchor=:x, title="pixel row")
		)
	)
end

# ╔═╡ baa00c8f-9fd4-44b7-bc79-669d17908c2d
cm"""
!!! note "What's ∘?"
	This is an operator that allows us to [compose functions](https://docs.julialang.org/en/v1/manual/functions/#Function-composition-and-piping) together.
""" |> msg

# ╔═╡ 80a54675-6662-4e66-b9a3-4746edc35c71
const DPATH = "https://github.com/icweaver/UCAN/raw/main/spectroscopy/data"

# ╔═╡ 95e3fec3-e03c-47c6-bdc4-7c93e0801718
ev_live = load(download(joinpath(DPATH, "castor.png")))

# ╔═╡ 81307d16-74d2-462a-8bb9-936dafb27dd7
img_info(ev_live);

# ╔═╡ 8a2e3efc-670b-4ce0-8d8f-fb95b1b0676b
# Convert to grayscale
arr_ev_live = ev_live .|> Gray |> channelview;

# ╔═╡ 4406e5d7-9a75-480b-8a97-b92e6a064338
@bind limits_ev_live let
	p = plot(
		heatmap(;
			z = arr_ev_live,
			showscale = false
		),
		Layout(
			xaxis = attr(title="column"),
			yaxis = attr(
				title = "row",
				autorange = "reversed",
				# scaleanchor = :x,
			),
			margin = attr(t=0, r=10,),
		)
	)

	add_plotly_listener!(p, "plotly_relayout", "
		e => {
		let layout = PLOT.layout
		PLOT.value = {xaxis: layout.xaxis.range, yaxis:layout.yaxis.range}
		PLOT.dispatchEvent(new CustomEvent('input'))
		}
		"
	)
end

# ╔═╡ 1898e267-84e5-4d76-adc3-086b1bfef3cd
prof_1D_ev_live, xrange_ev_live = compute_spec1D(arr_ev_live, limits_ev_live);

# ╔═╡ 352ddf83-7ef4-487e-912e-c3e2b8ad055c
p_spec1D_ev_live = plot(xrange_ev_live, prof_1D_ev_live, Layout(
	xaxis = attr(title="column"),
	yaxis = attr(title="intensity"),
	margin = attr(t=10, r=10,),
))

# ╔═╡ c6617828-9ab4-4a60-bac2-78ec9b5f8fac
p_spec1D_ev_live

# ╔═╡ f6ac23d4-e63d-4914-aff0-fb47edc02e7c
cm"""
$(@bind px_0 NumberField(xrange_ev_live)) Zero-point (px)

$(@bind px_line NumberField(xrange_ev_live)) H-β (Å)
"""

# ╔═╡ 447de825-9442-48ba-b373-2adc158799e3
λ(d, px) = d * (px - px_0);

# ╔═╡ b9bd59c7-f731-4d8b-a5f9-c96cea8d0b74
# Load FITS file
img_fits = load(download(joinpath(DPATH, "HD123657.fits")));

# ╔═╡ 178d3b56-4963-4bcc-b490-e5b6550acda3
img_info(img_fits);

# ╔═╡ 3357c912-78e4-4c90-a784-55e489bbaf02
# Get array data and swap rows/cols to match plotting convention
arr_fits = img_fits.data |> permutedims;

# ╔═╡ 60367274-b695-43f1-b16a-7c63fc9ef21a
@bind limits_ev_fits let
	p = plot(heatmap(; z=arr_fits, showscale=false), Layout(
		xaxis = attr(title="column"),
		yaxis = attr(title="row", autorange="reversed"),
	))

	add_plotly_listener!(p, "plotly_relayout", "
		e => {
		let layout = PLOT.layout
		PLOT.value = {xaxis: layout.xaxis.range, yaxis:layout.yaxis.range}
		PLOT.dispatchEvent(new CustomEvent('input'))
		}
		"
	)
end

# ╔═╡ c47acd38-7c27-4d02-9f95-f9a7df93a4cd
prof_1D_fits, xrange_ev_fits = compute_spec1D(arr_fits, limits_ev_fits);

# ╔═╡ f9868858-6982-4906-8b52-38e058e98279
plot(xrange_ev_fits, prof_1D_fits, Layout(
	xaxis = attr(title="column"),
	yaxis = attr(title="intensity"),
))

# ╔═╡ 229088f2-922f-4b93-b6c1-63f683a4ae0f
const ref_wavs = Dict(
		:h_alpha => 6562.8,
		:h_beta => 4861.4,
		:h_gamma => 4340.5,
		:h_delta => 4102.7,
		:h_epsilon => 3970.1,
	)

# ╔═╡ 0b681466-bd74-4a4f-8c0f-6cb9186a3af8
λ_line = ref_wavs[:h_beta];

# ╔═╡ f6fcc525-e1ef-48b1-9a28-7caa5e68b334
d = λ_line / (px_line - px_0);

# ╔═╡ 71c3f396-600b-40fc-b6a6-a796bd634a76
λ_ev_live = λ.(d, xrange_ev_live);

# ╔═╡ 3527ba04-3ea7-42ed-910e-ec72939a4c96
if 8.4 ≤ d ≤ 8.79
	cm"""
	!!! tip "Success 🎉"
		Congratulations, you have successfully calibrated your 1D spectrum!
	
		We hope that this brief introduction to analyzing spectra has provided you with some general tools for tackling your own datasets, and inspiration to explore further interesting topics in this field. Below are a few potential items that may be of interest for extending the techniques developed here.
	
		!!! note "Extension ideas"
			* Pixel binning
			* Image stacking
			* Background subtraction
			* Non-linear wavelength calibration
	
	"""
else
	cm"""
	!!! warning "Not quite"
		Try double checking which line is the H-β feature. A reference calibration sheet like [this one](https://www.aavso.org/sites/default/files/Calibration_Cheat_Sheet.png) may be helpful.
	"""
end

# ╔═╡ 272654a7-665f-48ee-beb5-13944c803e7e
let
	p = plot(λ_ev_live, prof_1D_ev_live, Layout(
		xaxis = attr(title="wavelength (Å)"),
		yaxis = attr(title="intensity"),
		title = "Dispersion: $(round(d; digits=2)) Å/pixel",
	))

	# Overlay reference lines
	show_lines && for (name, wav) ∈ ref_wavs
		add_vline!(p, wav; line_color=:darkgrey, line_width=1)
	end
	p
end

# ╔═╡ fcdedf52-2601-48c7-ad3b-7e74ca9aa1e6
md"""
## Packages
"""

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
AstroImages = "fe3fc30c-9b16-11e9-1c73-17dabf39f4ad"
CommonMark = "a80b9123-70ca-4bc0-993e-6e3bcb318db6"
Downloads = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
Images = "916415d5-f1e6-5110-898d-aaa5f9f070e0"
JSON = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
PlutoPlotly = "8e989ff0-3d88-8e9f-f020-2b208a939ff0"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"

[compat]
AstroImages = "~0.5.1"
CommonMark = "~0.8.12"
Images = "~0.26.1"
JSON = "~0.21.4"
PlutoPlotly = "~0.6.3"
PlutoUI = "~0.7.59"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.11.5"
manifest_format = "2.0"
project_hash = "cd61cd7854886998ca0a23af02ad5366f4a53d66"

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
git-tree-sha1 = "f7817e2e585aa6d924fd714df1e2a84be7896c60"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "4.3.0"
weakdeps = ["SparseArrays", "StaticArrays"]

    [deps.Adapt.extensions]
    AdaptSparseArraysExt = "SparseArrays"
    AdaptStaticArraysExt = "StaticArrays"

[[deps.AliasTables]]
deps = ["PtrArrays", "Random"]
git-tree-sha1 = "9876e1e164b144ca45e9e3198d0b689cadfed9ff"
uuid = "66dad0bd-aa9a-41b7-9441-69ab47430ed8"
version = "1.1.3"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.2"

[[deps.ArnoldiMethod]]
deps = ["LinearAlgebra", "Random", "StaticArrays"]
git-tree-sha1 = "d57bd3762d308bded22c3b82d033bff85f6195c6"
uuid = "ec485272-7323-5ecc-a04f-4719b315124d"
version = "0.4.0"

[[deps.ArrayInterface]]
deps = ["Adapt", "LinearAlgebra"]
git-tree-sha1 = "9606d7832795cbef89e06a550475be300364a8aa"
uuid = "4fba245c-0d91-5ea0-9b3e-6abc04ee57a9"
version = "7.19.0"

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
git-tree-sha1 = "bc188d9a6507511e7360444d54ed57d0a9d6cf91"
uuid = "5c4adb95-c1fc-4c53-b4ea-2a94080c53d2"
version = "0.2.0"

[[deps.AstroImages]]
deps = ["AbstractFFTs", "AstroAngles", "ColorSchemes", "DimensionalData", "FITSIO", "FileIO", "ImageAxes", "ImageBase", "ImageIO", "ImageShow", "MappedArrays", "PlotUtils", "PrecompileTools", "Printf", "RecipesBase", "Statistics", "Tables", "UUIDs", "WCS"]
git-tree-sha1 = "b036ab0541311fee6f278e1469b7839cc3af8f19"
uuid = "fe3fc30c-9b16-11e9-1c73-17dabf39f4ad"
version = "0.5.1"

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

[[deps.BitTwiddlingConvenienceFunctions]]
deps = ["Static"]
git-tree-sha1 = "f21cfd4950cb9f0587d5067e69405ad2acd27b87"
uuid = "62783981-4cbd-42fc-bca8-16325de8dc4b"
version = "0.1.6"

[[deps.Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1b96ea4a01afe0ea4090c5c8039690672dd13f2e"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.9+0"

[[deps.CEnum]]
git-tree-sha1 = "389ad5c84de1ae7cf0e28e381131c98ea87d54fc"
uuid = "fa961155-64e5-5f13-b03f-caf6b980ea82"
version = "0.5.0"

[[deps.CFITSIO]]
deps = ["CFITSIO_jll"]
git-tree-sha1 = "8c6b984c3928736d455eb53a6adf881457825269"
uuid = "3b1b4be9-1499-4b22-8d78-7db3344d1961"
version = "1.7.2"

[[deps.CFITSIO_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "LibCURL_jll", "Libdl", "Zlib_jll"]
git-tree-sha1 = "15e80be798d7711411f4ac4273144cdb2a89eb2f"
uuid = "b3e40c51-02ae-5482-8a39-3ace5868dcf4"
version = "4.6.2+0"

[[deps.CPUSummary]]
deps = ["CpuId", "IfElse", "PrecompileTools", "Static"]
git-tree-sha1 = "5a97e67919535d6841172016c9530fd69494e5ec"
uuid = "2a0fbf3d-bb9c-48f3-b0a9-814d99fd7ab9"
version = "0.2.6"

[[deps.CatIndices]]
deps = ["CustomUnitRanges", "OffsetArrays"]
git-tree-sha1 = "a0f80a09780eed9b1d106a1bf62041c2efc995bc"
uuid = "aafaddc9-749c-510e-ac4f-586e18779b91"
version = "0.2.2"

[[deps.ChainRulesCore]]
deps = ["Compat", "LinearAlgebra"]
git-tree-sha1 = "1713c74e00545bfe14605d2a2be1712de8fbcb58"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.25.1"
weakdeps = ["SparseArrays"]

    [deps.ChainRulesCore.extensions]
    ChainRulesCoreSparseArraysExt = "SparseArrays"

[[deps.CloseOpenIntervals]]
deps = ["Static", "StaticArrayInterface"]
git-tree-sha1 = "05ba0d07cd4fd8b7a39541e31a7b0254704ea581"
uuid = "fb6a15b2-703c-40df-9091-08a04967cfa9"
version = "0.1.13"

[[deps.Clustering]]
deps = ["Distances", "LinearAlgebra", "NearestNeighbors", "Printf", "Random", "SparseArrays", "Statistics", "StatsBase"]
git-tree-sha1 = "3e22db924e2945282e70c33b75d4dde8bfa44c94"
uuid = "aaaa29a8-35af-508c-8bc3-b662a17a0fe5"
version = "0.15.8"

[[deps.ColorSchemes]]
deps = ["ColorTypes", "ColorVectorSpace", "Colors", "FixedPointNumbers", "PrecompileTools", "Random"]
git-tree-sha1 = "403f2d8e209681fcbd9468a8514efff3ea08452e"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.29.0"

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
git-tree-sha1 = "5fdf00d1979fd4883b44b754fc3423175c9504b4"
uuid = "a80b9123-70ca-4bc0-993e-6e3bcb318db6"
version = "0.8.16"

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

[[deps.ComputationalResources]]
git-tree-sha1 = "52cb3ec90e8a8bea0e62e275ba577ad0f74821f7"
uuid = "ed09eef8-17a6-5b46-8889-db040fac31e3"
version = "0.3.2"

[[deps.ConstructionBase]]
git-tree-sha1 = "b4b092499347b18a015186eae3042f72267106cb"
uuid = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
version = "1.6.0"
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

[[deps.CpuId]]
deps = ["Markdown"]
git-tree-sha1 = "fcbb72b032692610bfbdb15018ac16a36cf2e406"
uuid = "adafc99b-e345-5852-983c-f28acb93d879"
version = "0.3.1"

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

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "4e1fe97fdaed23e9dc21d4d664bea76b65fc50a0"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.22"

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
deps = ["Adapt", "ArrayInterface", "ConstructionBase", "DataAPI", "Dates", "Extents", "Interfaces", "IntervalSets", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "OrderedCollections", "PrecompileTools", "Random", "RecipesBase", "SparseArrays", "Statistics", "TableTraits", "Tables"]
git-tree-sha1 = "b628bd06173897d44ab5cb5122e4a31509997c5a"
uuid = "0703355e-b756-11e9-17c0-8b28908087d0"
version = "0.29.17"

    [deps.DimensionalData.extensions]
    DimensionalDataAlgebraOfGraphicsExt = "AlgebraOfGraphics"
    DimensionalDataCategoricalArraysExt = "CategoricalArrays"
    DimensionalDataDiskArraysExt = "DiskArrays"
    DimensionalDataMakie = "Makie"
    DimensionalDataNearestNeighborsExt = "NearestNeighbors"
    DimensionalDataPythonCall = "PythonCall"
    DimensionalDataStatsBase = "StatsBase"

    [deps.DimensionalData.weakdeps]
    AlgebraOfGraphics = "cbdf2221-f076-402e-a563-3d30da359d67"
    CategoricalArrays = "324d7699-5711-5eae-9e2f-1d82baa6b597"
    DiskArrays = "3c3547ce-8d99-4f5e-a174-61eb10b00ae3"
    Makie = "ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a"
    NearestNeighbors = "b8a86587-4115-5ab1-83bc-aa920d37bbce"
    PythonCall = "6099a3de-0909-46bc-b1f4-468b9a2dfc0d"
    StatsBase = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"

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
git-tree-sha1 = "7442a5dfe1ebb773c29cc2962a8980f47221d76c"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.5"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.Extents]]
git-tree-sha1 = "b309b36a9e02fe7be71270dd8c0fd873625332b4"
uuid = "411431e0-e8b7-467b-b5e0-f676ba4f2910"
version = "0.1.6"

[[deps.FFTViews]]
deps = ["CustomUnitRanges", "FFTW"]
git-tree-sha1 = "cbdf14d1e8c7c8aacbe8b19862e0179fd08321c2"
uuid = "4f61f5a4-77b1-5117-aa51-3ab5ef4ef0cd"
version = "0.3.2"

[[deps.FFTW]]
deps = ["AbstractFFTs", "FFTW_jll", "LinearAlgebra", "MKL_jll", "Preferences", "Reexport"]
git-tree-sha1 = "797762812ed063b9b94f6cc7742bc8883bb5e69e"
uuid = "7a1cc6ca-52ef-59f5-83cd-3a7055c09341"
version = "1.9.0"

[[deps.FFTW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "6d6219a004b8cf1e0b4dbe27a2860b8e04eba0be"
uuid = "f5851436-0d7a-5f13-b9de-f02708fd171a"
version = "3.3.11+0"

[[deps.FITSIO]]
deps = ["CFITSIO", "Printf", "Reexport", "Tables"]
git-tree-sha1 = "f57de3f533590c785210893030736dc11c4a4afb"
uuid = "525bcba6-941b-5504-bd06-fd0dc1a4d2eb"
version = "0.17.5"

[[deps.FileIO]]
deps = ["Pkg", "Requires", "UUIDs"]
git-tree-sha1 = "b66970a70db13f45b7e57fbda1736e1cf72174ea"
uuid = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
version = "1.17.0"

    [deps.FileIO.extensions]
    HTTPExt = "HTTP"

    [deps.FileIO.weakdeps]
    HTTP = "cd3eb016-35fb-5094-929b-558a96fad6f3"

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

[[deps.Ghostscript_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "43ba3d3c82c18d88471cfd2924931658838c9d8f"
uuid = "61579ee1-b43e-5ca0-a5da-69d92c66a64b"
version = "9.55.0+4"

[[deps.Giflib_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "6570366d757b50fabae9f4315ad74d2e40c0560a"
uuid = "59f7168a-df46-5410-90c8-f2779963d0ec"
version = "5.2.3+0"

[[deps.Graphics]]
deps = ["Colors", "LinearAlgebra", "NaNMath"]
git-tree-sha1 = "a641238db938fff9b2f60d08ed9030387daf428c"
uuid = "a2bd30eb-e257-5431-a919-1863eab51364"
version = "1.1.3"

[[deps.Graphs]]
deps = ["ArnoldiMethod", "DataStructures", "Distributed", "Inflate", "LinearAlgebra", "Random", "SharedArrays", "SimpleTraits", "SparseArrays", "Statistics"]
git-tree-sha1 = "c5abfa0ae0aaee162a3fbb053c13ecda39be545b"
uuid = "86223c79-3864-5bf0-83f7-82e725a168b6"
version = "1.13.0"

[[deps.HashArrayMappedTries]]
git-tree-sha1 = "2eaa69a7cab70a52b9687c8bf950a5a93ec895ae"
uuid = "076d061b-32b6-4027-95e0-9a2c6f6d7e74"
version = "0.2.0"

[[deps.HistogramThresholding]]
deps = ["ImageBase", "LinearAlgebra", "MappedArrays"]
git-tree-sha1 = "7194dfbb2f8d945abdaf68fa9480a965d6661e69"
uuid = "2c695a8d-9458-5d45-9878-1b8a99cf7853"
version = "0.3.1"

[[deps.HostCPUFeatures]]
deps = ["BitTwiddlingConvenienceFunctions", "IfElse", "Libdl", "Static"]
git-tree-sha1 = "8e070b599339d622e9a081d17230d74a5c473293"
uuid = "3e5b6fbb-0976-4d2c-9146-d79de83f2fb0"
version = "0.1.17"

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
git-tree-sha1 = "e12629406c6c4442539436581041d372d69c55ba"
uuid = "2803e5a7-5153-5ecf-9a86-9b4c37f5f5ac"
version = "0.6.12"

[[deps.ImageBase]]
deps = ["ImageCore", "Reexport"]
git-tree-sha1 = "eb49b82c172811fd2c86759fa0553a2221feb909"
uuid = "c817782e-172a-44cc-b673-b171935fbb9e"
version = "0.1.7"

[[deps.ImageBinarization]]
deps = ["HistogramThresholding", "ImageCore", "LinearAlgebra", "Polynomials", "Reexport", "Statistics"]
git-tree-sha1 = "33485b4e40d1df46c806498c73ea32dc17475c59"
uuid = "cbc4b850-ae4b-5111-9e64-df94c024a13d"
version = "0.3.1"

[[deps.ImageContrastAdjustment]]
deps = ["ImageBase", "ImageCore", "ImageTransformations", "Parameters"]
git-tree-sha1 = "eb3d4365a10e3f3ecb3b115e9d12db131d28a386"
uuid = "f332f351-ec65-5f6a-b3d1-319c6670881a"
version = "0.3.12"

[[deps.ImageCore]]
deps = ["ColorVectorSpace", "Colors", "FixedPointNumbers", "MappedArrays", "MosaicViews", "OffsetArrays", "PaddedViews", "PrecompileTools", "Reexport"]
git-tree-sha1 = "8c193230235bbcee22c8066b0374f63b5683c2d3"
uuid = "a09fc81d-aa75-5fe9-8630-4744c3626534"
version = "0.10.5"

[[deps.ImageCorners]]
deps = ["ImageCore", "ImageFiltering", "PrecompileTools", "StaticArrays", "StatsBase"]
git-tree-sha1 = "24c52de051293745a9bad7d73497708954562b79"
uuid = "89d5987c-236e-4e32-acd0-25bd6bd87b70"
version = "0.1.3"

[[deps.ImageDistances]]
deps = ["Distances", "ImageCore", "ImageMorphology", "LinearAlgebra", "Statistics"]
git-tree-sha1 = "08b0e6354b21ef5dd5e49026028e41831401aca8"
uuid = "51556ac3-7006-55f5-8cb3-34580c88182d"
version = "0.2.17"

[[deps.ImageFiltering]]
deps = ["CatIndices", "ComputationalResources", "DataStructures", "FFTViews", "FFTW", "ImageBase", "ImageCore", "LinearAlgebra", "OffsetArrays", "PrecompileTools", "Reexport", "SparseArrays", "StaticArrays", "Statistics", "TiledIteration"]
git-tree-sha1 = "eea3a5095c0c5f143e62773164ab11f67e43c4bb"
uuid = "6a3955dd-da59-5b1f-98d4-e7296123deb5"
version = "0.7.10"

[[deps.ImageIO]]
deps = ["FileIO", "IndirectArrays", "JpegTurbo", "LazyModules", "Netpbm", "OpenEXR", "PNGFiles", "QOI", "Sixel", "TiffImages", "UUIDs", "WebP"]
git-tree-sha1 = "696144904b76e1ca433b886b4e7edd067d76cbf7"
uuid = "82e4d734-157c-48bb-816b-45c225c6df19"
version = "0.6.9"

[[deps.ImageMagick]]
deps = ["FileIO", "ImageCore", "ImageMagick_jll", "InteractiveUtils"]
git-tree-sha1 = "8e64ab2f0da7b928c8ae889c514a52741debc1c2"
uuid = "6218d12a-5da1-5696-b52f-db25d2ecc6d1"
version = "1.4.2"

[[deps.ImageMagick_jll]]
deps = ["Artifacts", "Ghostscript_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libtiff_jll", "OpenJpeg_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "afde851466407a99d48829051c36ac80749d8d7c"
uuid = "c73af94c-d91f-53ed-93a7-00f77d67a9d7"
version = "7.1.1048+0"

[[deps.ImageMetadata]]
deps = ["AxisArrays", "ImageAxes", "ImageBase", "ImageCore"]
git-tree-sha1 = "2a81c3897be6fbcde0802a0ebe6796d0562f63ec"
uuid = "bc367c6b-8a6b-528e-b4bd-a4b897500b49"
version = "0.9.10"

[[deps.ImageMorphology]]
deps = ["DataStructures", "ImageCore", "LinearAlgebra", "LoopVectorization", "OffsetArrays", "Requires", "TiledIteration"]
git-tree-sha1 = "cffa21df12f00ca1a365eb8ed107614b40e8c6da"
uuid = "787d08f9-d448-5407-9aad-5290dd7ab264"
version = "0.4.6"

[[deps.ImageQualityIndexes]]
deps = ["ImageContrastAdjustment", "ImageCore", "ImageDistances", "ImageFiltering", "LazyModules", "OffsetArrays", "PrecompileTools", "Statistics"]
git-tree-sha1 = "783b70725ed326340adf225be4889906c96b8fd1"
uuid = "2996bd0c-7a13-11e9-2da2-2f5ce47296a9"
version = "0.3.7"

[[deps.ImageSegmentation]]
deps = ["Clustering", "DataStructures", "Distances", "Graphs", "ImageCore", "ImageFiltering", "ImageMorphology", "LinearAlgebra", "MetaGraphs", "RegionTrees", "SimpleWeightedGraphs", "StaticArrays", "Statistics"]
git-tree-sha1 = "7196039573b6f312864547eb7a74360d6c0ab8e6"
uuid = "80713f31-8817-5129-9cf8-209ff8fb23e1"
version = "1.9.0"

[[deps.ImageShow]]
deps = ["Base64", "ColorSchemes", "FileIO", "ImageBase", "ImageCore", "OffsetArrays", "StackViews"]
git-tree-sha1 = "3b5344bcdbdc11ad58f3b1956709b5b9345355de"
uuid = "4e3cecfd-b093-5904-9786-8bbb286a6a31"
version = "0.3.8"

[[deps.ImageTransformations]]
deps = ["AxisAlgorithms", "CoordinateTransformations", "ImageBase", "ImageCore", "Interpolations", "OffsetArrays", "Rotations", "StaticArrays"]
git-tree-sha1 = "dfde81fafbe5d6516fb864dc79362c5c6b973c82"
uuid = "02fcd773-0e25-5acc-982a-7f6622650795"
version = "0.10.2"

[[deps.Images]]
deps = ["Base64", "FileIO", "Graphics", "ImageAxes", "ImageBase", "ImageBinarization", "ImageContrastAdjustment", "ImageCore", "ImageCorners", "ImageDistances", "ImageFiltering", "ImageIO", "ImageMagick", "ImageMetadata", "ImageMorphology", "ImageQualityIndexes", "ImageSegmentation", "ImageShow", "ImageTransformations", "IndirectArrays", "IntegralArrays", "Random", "Reexport", "SparseArrays", "StaticArrays", "Statistics", "StatsBase", "TiledIteration"]
git-tree-sha1 = "a49b96fd4a8d1a9a718dfd9cde34c154fc84fcd5"
uuid = "916415d5-f1e6-5110-898d-aaa5f9f070e0"
version = "0.26.2"

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

[[deps.IntegralArrays]]
deps = ["ColorTypes", "FixedPointNumbers", "IntervalSets"]
git-tree-sha1 = "b842cbff3f44804a84fda409745cc8f04c029a20"
uuid = "1d092043-8f09-5a30-832f-7509e371ab51"
version = "0.1.6"

[[deps.IntelOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "LazyArtifacts", "Libdl"]
git-tree-sha1 = "0f14a5456bdc6b9731a5682f439a672750a09e48"
uuid = "1d5cc7b8-4909-519e-a0f8-d0f5ad9712d0"
version = "2025.0.4+0"

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
git-tree-sha1 = "f2905febca224eade352a573e129ef43aa593354"
uuid = "a98d9a8b-a2ab-59e6-89dd-64a1c18fca59"
version = "0.16.1"

    [deps.Interpolations.extensions]
    InterpolationsForwardDiffExt = "ForwardDiff"
    InterpolationsUnitfulExt = "Unitful"

    [deps.Interpolations.weakdeps]
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[[deps.IntervalSets]]
git-tree-sha1 = "5fbb102dcb8b1a858111ae81d56682376130517d"
uuid = "8197267c-284f-5f27-9208-e0e47529a953"
version = "0.7.11"
weakdeps = ["Random", "RecipesBase", "Statistics"]

    [deps.IntervalSets.extensions]
    IntervalSetsRandomExt = "Random"
    IntervalSetsRecipesBaseExt = "RecipesBase"
    IntervalSetsStatisticsExt = "Statistics"

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

[[deps.JLD2]]
deps = ["FileIO", "MacroTools", "Mmap", "OrderedCollections", "PrecompileTools", "TranscodingStreams"]
git-tree-sha1 = "8e071648610caa2d3a5351aba03a936a0c37ec61"
uuid = "033835bb-8acc-5ee8-8aae-3f567f8a3819"
version = "0.5.13"
weakdeps = ["UnPack"]

    [deps.JLD2.extensions]
    UnPackExt = "UnPack"

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
git-tree-sha1 = "9496de8fb52c224a2e3f9ff403947674517317d9"
uuid = "b835a17e-a41a-41e7-81f0-2f016b05efe0"
version = "0.1.6"

[[deps.JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "eac1206917768cb54957c65a615460d87b455fc1"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "3.1.1+0"

[[deps.LERC_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "bf36f528eec6634efc60d7ec062008f171071434"
uuid = "88015f11-f218-50d7-93a8-a6af411a945d"
version = "3.0.0+1"

[[deps.LaTeXStrings]]
git-tree-sha1 = "dda21b8cbd6a6c40d9d02a73230f9d70fed6918c"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.4.0"

[[deps.LayoutPointers]]
deps = ["ArrayInterface", "LinearAlgebra", "ManualMemory", "SIMDTypes", "Static", "StaticArrayInterface"]
git-tree-sha1 = "a9eaadb366f5493a5654e843864c13d8b107548c"
uuid = "10f19ff3-798f-405d-979b-55457f8fc047"
version = "0.1.17"

[[deps.LazyArtifacts]]
deps = ["Artifacts", "Pkg"]
uuid = "4af54fe1-eca0-43a8-85a7-787d91b784e3"
version = "1.11.0"

[[deps.LazyModules]]
git-tree-sha1 = "a560dd966b386ac9ae60bdd3a3d3a326062d3c3e"
uuid = "8cdb02fc-e678-4876-92c5-9defec4f444e"
version = "0.3.1"

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

[[deps.Libglvnd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll", "Xorg_libXext_jll"]
git-tree-sha1 = "d36c21b9e7c172a44a10484125024495e2625ac0"
uuid = "7e76a0d4-f3c7-5321-8279-8d96eeed0f29"
version = "1.7.1+1"

[[deps.Libtiff_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "LERC_jll", "Libdl", "XZ_jll", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "2da088d113af58221c52828a80378e16be7d037a"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.5.1+1"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
version = "1.11.0"

[[deps.LittleCMS_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libtiff_jll"]
git-tree-sha1 = "fa7fd067dca76cadd880f1ca937b4f387975a9f5"
uuid = "d3a379c0-f9a3-5b72-a4c0-6bf4d2e8af0f"
version = "2.16.0+0"

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

[[deps.LoopVectorization]]
deps = ["ArrayInterface", "CPUSummary", "CloseOpenIntervals", "DocStringExtensions", "HostCPUFeatures", "IfElse", "LayoutPointers", "LinearAlgebra", "OffsetArrays", "PolyesterWeave", "PrecompileTools", "SIMDTypes", "SLEEFPirates", "Static", "StaticArrayInterface", "ThreadingUtilities", "UnPack", "VectorizationBase"]
git-tree-sha1 = "e5afce7eaf5b5ca0d444bcb4dc4fd78c54cbbac0"
uuid = "bdcacae8-1622-11e9-2a5c-532679323890"
version = "0.12.172"

    [deps.LoopVectorization.extensions]
    ForwardDiffExt = ["ChainRulesCore", "ForwardDiff"]
    SpecialFunctionsExt = "SpecialFunctions"

    [deps.LoopVectorization.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    SpecialFunctions = "276daf66-3868-5448-9aa4-cd146d93841b"

[[deps.MIMEs]]
git-tree-sha1 = "c64d943587f7187e751162b3b84445bbbd79f691"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "1.1.0"

[[deps.MKL_jll]]
deps = ["Artifacts", "IntelOpenMP_jll", "JLLWrappers", "LazyArtifacts", "Libdl", "oneTBB_jll"]
git-tree-sha1 = "5de60bc6cb3899cd318d80d627560fae2e2d99ae"
uuid = "856f044c-d86e-5d09-b602-aeab76dc8ba7"
version = "2025.0.1+1"

[[deps.MacroTools]]
git-tree-sha1 = "1e0228a030642014fe5cfe68c2c0a818f9e3f522"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.16"

[[deps.ManualMemory]]
git-tree-sha1 = "bcaef4fc7a0cfe2cba636d84cda54b5e4e4ca3cd"
uuid = "d125e4d3-2237-4719-b19c-fa641b8a4667"
version = "0.1.8"

[[deps.MappedArrays]]
git-tree-sha1 = "2dab0221fe2b0f2cb6754eaa743cc266339f527e"
uuid = "dbb5928d-eab1-5f90-85c2-b9b0edb7c900"
version = "0.4.2"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"
version = "1.11.0"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.6+0"

[[deps.MetaGraphs]]
deps = ["Graphs", "JLD2", "Random"]
git-tree-sha1 = "e9650bea7f91c3397eb9ae6377343963a22bf5b8"
uuid = "626554b9-1ddb-594c-aa3c-2596fe9399a5"
version = "0.8.0"

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

[[deps.NaNMath]]
deps = ["OpenLibm_jll"]
git-tree-sha1 = "9b8215b1ee9e78a293f99797cd31375471b2bcae"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "1.1.3"

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
git-tree-sha1 = "117432e406b5c023f665fa73dc26e79ec3630151"
uuid = "6fe1bfb0-de20-5000-8ca7-80f57d26f881"
version = "1.17.0"
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

[[deps.OpenJpeg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libtiff_jll", "LittleCMS_jll", "libpng_jll"]
git-tree-sha1 = "7dc7028a10d1408e9103c0a77da19fdedce4de6c"
uuid = "643b3616-a352-519d-856d-80112ee9badc"
version = "2.5.4+0"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"
version = "0.8.5+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "05868e21324cede2207c6f0f466b4bfef6d5e7ee"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.8.1"

[[deps.PNGFiles]]
deps = ["Base64", "CEnum", "ImageCore", "IndirectArrays", "OffsetArrays", "libpng_jll"]
git-tree-sha1 = "cf181f0b1e6a18dfeb0ee8acc4a9d1672499626c"
uuid = "f57f5aa1-a3ce-4bc8-8ab9-96f992907883"
version = "0.4.4"

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
git-tree-sha1 = "7d2f8f21da5db6a806faf7b9b292296da42b2810"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.8.3"

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
deps = ["ColorSchemes", "Colors", "Dates", "DelimitedFiles", "DocStringExtensions", "JSON", "LaTeXStrings", "Logging", "Parameters", "Pkg", "REPL", "Requires", "Statistics", "UUIDs"]
git-tree-sha1 = "28278bb0053da0fd73537be94afd1682cc5a0a83"
uuid = "a03496cd-edff-5a9b-9e67-9cda94a718b5"
version = "0.8.21"

    [deps.PlotlyBase.extensions]
    DataFramesExt = "DataFrames"
    DistributionsExt = "Distributions"
    IJuliaExt = "IJulia"
    JSON3Ext = "JSON3"

    [deps.PlotlyBase.weakdeps]
    DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
    Distributions = "31c24e10-a181-5473-b8eb-7969acd0382f"
    IJulia = "7073ff75-c697-5162-941a-fcdaad2a7d2a"
    JSON3 = "0f8b85d8-7281-11e9-16c2-39a750bddbf1"

[[deps.PlutoPlotly]]
deps = ["AbstractPlutoDingetjes", "Artifacts", "ColorSchemes", "Colors", "Dates", "Downloads", "HypertextLiteral", "InteractiveUtils", "LaTeXStrings", "Markdown", "Pkg", "PlotlyBase", "PrecompileTools", "Reexport", "ScopedValues", "Scratch", "TOML"]
git-tree-sha1 = "4fb7c9595eaad32d817cac8c5fa1f90daa83aa4c"
uuid = "8e989ff0-3d88-8e9f-f020-2b208a939ff0"
version = "0.6.3"

    [deps.PlutoPlotly.extensions]
    PlotlyKaleidoExt = "PlotlyKaleido"
    UnitfulExt = "Unitful"

    [deps.PlutoPlotly.weakdeps]
    PlotlyKaleido = "f2990250-8cf9-495f-b13a-cce12b45703c"
    Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "3876f0ab0390136ae0b5e3f064a109b87fa1e56e"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.63"

[[deps.PolyesterWeave]]
deps = ["BitTwiddlingConvenienceFunctions", "CPUSummary", "IfElse", "Static", "ThreadingUtilities"]
git-tree-sha1 = "645bed98cd47f72f67316fd42fc47dee771aefcd"
uuid = "1d0040c9-8b98-4ee7-8388-3f51789ca0ad"
version = "0.2.2"

[[deps.Polynomials]]
deps = ["LinearAlgebra", "OrderedCollections", "RecipesBase", "Requires", "Setfield", "SparseArrays"]
git-tree-sha1 = "555c272d20fc80a2658587fb9bbda60067b93b7c"
uuid = "f27b6e38-b328-58d1-80ce-0feddd5e7a45"
version = "4.0.19"

    [deps.Polynomials.extensions]
    PolynomialsChainRulesCoreExt = "ChainRulesCore"
    PolynomialsFFTWExt = "FFTW"
    PolynomialsMakieCoreExt = "MakieCore"
    PolynomialsMutableArithmeticsExt = "MutableArithmetics"

    [deps.Polynomials.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    FFTW = "7a1cc6ca-52ef-59f5-83cd-3a7055c09341"
    MakieCore = "20f20a25-4f0e-4fdf-b5d1-57303727442b"
    MutableArithmetics = "d8a4904e-b15c-11e9-3269-09a3773c0cb0"

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

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"
version = "1.11.0"

[[deps.ProgressMeter]]
deps = ["Distributed", "Printf"]
git-tree-sha1 = "13c5103482a8ed1536a54c08d0e742ae3dca2d42"
uuid = "92933f4c-e287-5a05-a399-4b506db050ca"
version = "1.10.4"

[[deps.PtrArrays]]
git-tree-sha1 = "1d36ef11a9aaf1e8b74dacc6a731dd1de8fd493d"
uuid = "43287f4e-b6f4-7ad1-bb20-aadabca52c3d"
version = "1.3.0"

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

[[deps.RegionTrees]]
deps = ["IterTools", "LinearAlgebra", "StaticArrays"]
git-tree-sha1 = "4618ed0da7a251c7f92e869ae1a19c74a7d2a7f9"
uuid = "dee08c22-ab7f-5625-9660-a9af2021b33f"
version = "0.3.2"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "62389eeff14780bfe55195b7204c0d8738436d64"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.1"

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

[[deps.SIMDTypes]]
git-tree-sha1 = "330289636fb8107c5f32088d2741e9fd7a061a5c"
uuid = "94e857df-77ce-4151-89e5-788b33177be4"
version = "0.1.0"

[[deps.SLEEFPirates]]
deps = ["IfElse", "Static", "VectorizationBase"]
git-tree-sha1 = "456f610ca2fbd1c14f5fcf31c6bfadc55e7d66e0"
uuid = "476501e8-09a2-5ece-8869-fb82de89a1fa"
version = "0.6.43"

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

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"
version = "1.11.0"

[[deps.Setfield]]
deps = ["ConstructionBase", "Future", "MacroTools", "StaticArraysCore"]
git-tree-sha1 = "c5391c6ace3bc430ca630251d02ea9687169ca68"
uuid = "efcf1570-3423-57d1-acb7-fd33fddbac46"
version = "1.1.2"

[[deps.SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"
version = "1.11.0"

[[deps.SimpleTraits]]
deps = ["InteractiveUtils", "MacroTools"]
git-tree-sha1 = "5d7e3f4e11935503d3ecaf7186eac40602e7d231"
uuid = "699a6c99-e7fa-54fc-8d76-47d257e15c1d"
version = "0.9.4"

[[deps.SimpleWeightedGraphs]]
deps = ["Graphs", "LinearAlgebra", "Markdown", "SparseArrays"]
git-tree-sha1 = "3e5f165e58b18204aed03158664c4982d691f454"
uuid = "47aef6b3-ad0c-573a-a1e2-d07658019622"
version = "1.5.0"

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
git-tree-sha1 = "95af145932c2ed859b63329952ce8d633719f091"
uuid = "860ef19b-820b-49d6-a774-d7a799459cd3"
version = "1.0.3"

[[deps.StackViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "be1cf4eb0ac528d96f5115b4ed80c26a8d8ae621"
uuid = "cae243ae-269e-4f55-b966-ac2d0dc13c15"
version = "0.1.2"

[[deps.Static]]
deps = ["CommonWorldInvalidations", "IfElse", "PrecompileTools"]
git-tree-sha1 = "f737d444cb0ad07e61b3c1bef8eb91203c321eff"
uuid = "aedffcd0-7271-4cad-89d0-dc628f76c6d3"
version = "1.2.0"

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
git-tree-sha1 = "0feb6b9031bd5c51f9072393eb5ab3efd31bf9e4"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.9.13"
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
git-tree-sha1 = "9d72a13a3f4dd3795a195ac5a44d7d6ff5f552ff"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.7.1"

[[deps.StatsBase]]
deps = ["AliasTables", "DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "b81c5035922cc89c2d9523afc6c54be512411466"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.34.5"

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

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "OrderedCollections", "TableTraits"]
git-tree-sha1 = "f2c1efbc8f3a609aadf318094f8fc5204bdaf344"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.12.1"

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

[[deps.ThreadingUtilities]]
deps = ["ManualMemory"]
git-tree-sha1 = "2d529b6b22791f3e22e7ec5c60b9016e78f5f6bf"
uuid = "8290d209-cae3-49c0-8002-c8c24d57dab5"
version = "0.5.4"

[[deps.TiffImages]]
deps = ["ColorTypes", "DataStructures", "DocStringExtensions", "FileIO", "FixedPointNumbers", "IndirectArrays", "Inflate", "Mmap", "OffsetArrays", "PkgVersion", "PrecompileTools", "ProgressMeter", "SIMD", "UUIDs"]
git-tree-sha1 = "02aca429c9885d1109e58f400c333521c13d48a0"
uuid = "731e570b-9d59-4bfa-96dc-6df516fadf69"
version = "0.11.4"

[[deps.TiledIteration]]
deps = ["OffsetArrays", "StaticArrayInterface"]
git-tree-sha1 = "1176cc31e867217b06928e2f140c90bd1bc88283"
uuid = "06e1c1a7-607b-532d-9fad-de7d9aa2abac"
version = "0.5.0"

[[deps.TranscodingStreams]]
git-tree-sha1 = "0c45878dcfdcfa8480052b6ab162cdd138781742"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.11.3"

[[deps.Tricks]]
git-tree-sha1 = "6cae795a5a9313bbb4f60683f7263318fc7d1505"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.10"

[[deps.URIs]]
git-tree-sha1 = "cbbebadbcc76c5ca1cc4b4f3b0614b3e603b5000"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.5.2"

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

[[deps.VectorizationBase]]
deps = ["ArrayInterface", "CPUSummary", "HostCPUFeatures", "IfElse", "LayoutPointers", "Libdl", "LinearAlgebra", "SIMDTypes", "Static", "StaticArrayInterface"]
git-tree-sha1 = "4ab62a49f1d8d9548a1c8d1a75e5f55cf196f64e"
uuid = "3d5dd08c-fd9d-11e8-17fa-ed2836048c2f"
version = "0.21.71"

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

[[deps.XZ_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "fee71455b0aaa3440dfdd54a9a36ccef829be7d4"
uuid = "ffd25f8a-64ca-5728-b0f7-c24cf3aae800"
version = "5.8.1+0"

[[deps.Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "b5899b25d17bf1889d25906fb9deed5da0c15b3b"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.8.12+0"

[[deps.Xorg_libXau_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "aa1261ebbac3ccc8d16558ae6799524c450ed16b"
uuid = "0c0b7dd1-d40b-584c-a123-a41640f87eec"
version = "1.0.13+0"

[[deps.Xorg_libXdmcp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "52858d64353db33a56e13c341d7bf44cd0d7b309"
uuid = "a3789734-cfe1-5b06-b2d0-1dd0d9d62d05"
version = "1.1.6+0"

[[deps.Xorg_libXext_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll"]
git-tree-sha1 = "a4c0ee07ad36bf8bbce1c3bb52d21fb1e0b987fb"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.7+0"

[[deps.Xorg_libxcb_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libXau_jll", "Xorg_libXdmcp_jll"]
git-tree-sha1 = "bfcaf7ec088eaba362093393fe11aa141fa15422"
uuid = "c7cfdc94-dc32-55de-ac96-5a1b8d977c5b"
version = "1.17.1+0"

[[deps.Xorg_xtrans_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "a63799ff68005991f9d9491b6e95bd3478d783cb"
uuid = "c5fb5394-a638-5e4d-96e5-b29de1b5cf10"
version = "1.6.0+0"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+1"

[[deps.Zstd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "446b23e73536f84e8037f5dce465e92275f6a308"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.7+1"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.11.0+0"

[[deps.libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "002748401f7b520273e2b506f61cab95d4701ccf"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.48+0"

[[deps.libsixel_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "Libdl", "libpng_jll"]
git-tree-sha1 = "c1733e347283df07689d71d61e14be986e49e47a"
uuid = "075b6546-f08a-558a-be8f-8157d0f608a5"
version = "1.10.5+0"

[[deps.libwebp_jll]]
deps = ["Artifacts", "Giflib_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libglvnd_jll", "Libtiff_jll", "libpng_jll"]
git-tree-sha1 = "ccbb625a89ec6195856a50aa2b668a5c08712c94"
uuid = "c5f90fcd-3b7e-5836-afba-fc50a0988cb2"
version = "1.4.0+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.59.0+0"

[[deps.oneTBB_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "d5a767a3bb77135a99e433afe0eb14cd7f6914c3"
uuid = "1317d2d5-d96f-522e-a858-c73665f53c3e"
version = "2022.0.0+0"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+2"
"""

# ╔═╡ Cell order:
# ╟─bdf98bfb-ad09-4c02-9ef5-c02552b70ad5
# ╟─0968d0d2-7a53-47c5-be13-9c941c0fba0b
# ╟─1e2dc809-1614-487e-b0fe-f058188555ee
# ╟─7e3aedd9-6c94-42ce-aeaa-ea0c2d71a9b1
# ╟─127ca8df-46c7-4d02-8f9b-e27983978441
# ╟─30585bee-7751-47ca-bcf8-2b57af2b1394
# ╟─249dd9ce-239e-45a9-9f59-c8991ecd299f
# ╟─848cfcdc-d15e-4f8e-8729-a20bb50327fa
# ╟─0f3ae63c-cc02-43a8-9560-3770439640a0
# ╟─0b7dff7d-26d2-4c00-8d39-dceabb7433b6
# ╟─9f83d261-61c8-4ab2-9e2e-a9a2fe24f3a5
# ╟─bed3c1a0-aa13-4c61-a074-9b38f9a4d306
# ╟─c402e19e-05f6-4b4f-a9dc-f2036e415b17
# ╟─f102cbeb-edde-4814-94cb-0f8a8b73f836
# ╟─248c07d3-48ee-40a1-b9b5-d57f49b56d6f
# ╟─64a3d702-d229-4fd1-bd75-f351a4ee1172
# ╟─256f479b-7c90-4ad4-a893-e3e5c2266516
# ╟─9014873e-5b1b-4605-9dd6-efb9840e5732
# ╟─685c8647-3de7-4775-ba71-fdfd23c557de
# ╟─9427d980-2420-4285-992e-099bc6d1aa55
# ╟─0d260f11-abcd-404d-885a-ba02f2692e36
# ╟─cd2e384e-6f30-40b9-86f9-9a285a956b94
# ╟─9193e583-fe34-4a62-8142-5981e2335276
# ╟─5dc94909-7181-42be-a252-4fcfb6a84ff0
# ╟─6880b7a1-0a74-4879-bd85-90c8f8e947d2
# ╟─736e7f03-7eb9-4805-afe4-74170c046c4c
# ╟─9932a3b1-6d52-4ed1-8884-2f90f765ac68
# ╟─4ea2b324-39dc-4a36-a36b-96eca525e00c
# ╠═9edd83bf-bcae-4f39-940d-4265bdcd2c34
# ╟─d39b4688-a25e-4e47-9037-eeb7e3a6918c
# ╟─cf371199-c283-46e8-8174-31796e2224cb
# ╟─703050cd-57fc-4b8b-b631-d5b8124ef872
# ╟─cf940fd1-4f37-477a-ab46-e75902273f5d
# ╟─8c79235d-5b03-4e97-acaf-b3eea88e91b9
# ╠═c77bb96f-357e-4676-a504-ff93a5cd1711
# ╟─a2842f26-520e-42c0-bc4e-b04feccf22b2
# ╟─50e3b47b-4072-4be6-b740-efdf3dd9a3a2
# ╟─2f18fb1a-2178-4e12-b411-13fa49f3084f
# ╟─77836abd-a282-471b-a994-395781fc1f0b
# ╟─f5dfab17-a789-46dd-ae4f-d3707d0a4573
# ╟─bb008a9b-8538-418d-9e70-50d9983c2074
# ╠═096b8d1e-9092-4110-95a7-7cff9210ba43
# ╟─fedb57fe-574c-4567-933a-052e9b8d50bd
# ╠═fcc96529-3b20-4a59-9d2d-48612f4c16f3
# ╟─f7f490fe-32d5-4a00-a12a-07bfcc1d3edf
# ╟─9e16a591-4d89-4d90-a96f-eed8f2078dad
# ╠═12c0a504-856d-40b0-aa01-bbb992167943
# ╟─14f83f54-f51c-4af4-b388-b76f188e7649
# ╠═d0203d68-6a55-46ec-ab8f-8fdfc5b1356d
# ╟─c37fc603-8943-4be6-9c73-1f327e8b7885
# ╟─d4ca722f-ebc8-411d-a2f1-48fb83373e54
# ╟─2f5da861-2a83-4ed1-9b6b-f9081768ca05
# ╟─d3b6afc1-c29b-476a-90ed-721796af130f
# ╟─1cef03ec-1991-4491-a415-c711ea457e05
# ╟─7e3e9ccc-5ed8-4067-b944-aac86e3a2cb8
# ╟─7616d2b0-9a2f-467e-91a6-da321717791f
# ╟─ee3ee62d-1548-4b13-afac-ea50cdec1ba5
# ╟─715d8d40-3ba1-4244-90e7-f4a5e1d76a1f
# ╠═95e3fec3-e03c-47c6-bdc4-7c93e0801718
# ╟─81307d16-74d2-462a-8bb9-936dafb27dd7
# ╟─01ee9b23-caa3-49d6-aff4-972ea7be2d79
# ╟─4406e5d7-9a75-480b-8a97-b92e6a064338
# ╟─352ddf83-7ef4-487e-912e-c3e2b8ad055c
# ╟─07d7dd41-8b49-4afc-9da2-b977473b24a3
# ╟─27ad53e4-40c6-4d2e-a87b-d766f048c4bd
# ╟─d25e3ef6-c9a8-4219-81cd-04202187e347
# ╟─b4f43581-09e8-45f8-bdc1-766dd88bdfc3
# ╠═8a2e3efc-670b-4ce0-8d8f-fb95b1b0676b
# ╠═1898e267-84e5-4d76-adc3-086b1bfef3cd
# ╟─7e60b93f-b57f-48fe-a196-a36c3d1f8cb6
# ╟─f7dd6681-2792-4753-b016-2c7358a343a9
# ╟─7d052ff9-f0dd-4ce7-a5c8-5eed191ae467
# ╟─a412dd91-f4bd-4d55-933e-3a6d00db4ab0
# ╟─70040896-2bd3-43a1-adfa-2114424e42e7
# ╟─27642020-21e5-4de1-9f67-a951a6a682ed
# ╟─178d3b56-4963-4bcc-b490-e5b6550acda3
# ╟─60367274-b695-43f1-b16a-7c63fc9ef21a
# ╟─f9868858-6982-4906-8b52-38e058e98279
# ╟─b3dacdf9-f45f-40b8-b463-eac43ceb7e87
# ╟─2c163542-8825-491c-8277-6097da40221f
# ╠═b9bd59c7-f731-4d8b-a5f9-c96cea8d0b74
# ╠═3357c912-78e4-4c90-a784-55e489bbaf02
# ╠═c47acd38-7c27-4d02-9f95-f9a7df93a4cd
# ╟─25326216-a51b-4e9c-a484-3853ae135a16
# ╟─2c36115d-c399-404a-80f0-1a8ee3223cb1
# ╟─25002ec9-6c1a-47e8-aebf-64b2c649c0c7
# ╠═0b681466-bd74-4a4f-8c0f-6cb9186a3af8
# ╠═f6fcc525-e1ef-48b1-9a28-7caa5e68b334
# ╠═447de825-9442-48ba-b373-2adc158799e3
# ╠═71c3f396-600b-40fc-b6a6-a796bd634a76
# ╟─c6617828-9ab4-4a60-bac2-78ec9b5f8fac
# ╟─307c7c22-5dbf-4134-beaf-815bcfeb2e65
# ╟─f6ac23d4-e63d-4914-aff0-fb47edc02e7c
# ╟─e3cc6aff-b777-4391-97b2-f24f288127c5
# ╟─272654a7-665f-48ee-beb5-13944c803e7e
# ╟─3527ba04-3ea7-42ed-910e-ec72939a4c96
# ╟─bdb84f9c-4eef-494d-8d8f-d70fe35286ac
# ╠═46deb312-8f07-4b4e-a5b4-b852fb1d016d
# ╟─5b638405-5f75-473c-9de9-6acac9856608
# ╟─4c6a8538-2124-44f0-9891-4a3e1472ea4e
# ╟─e1ae334d-548b-4259-af7c-e13b773f7b3e
# ╟─75108863-4a62-4751-aeee-246250fbf8b8
# ╟─7d1caf58-d1db-4fcb-a62b-5c2a16b56732
# ╟─baa00c8f-9fd4-44b7-bc79-669d17908c2d
# ╟─80a54675-6662-4e66-b9a3-4746edc35c71
# ╟─229088f2-922f-4b93-b6c1-63f683a4ae0f
# ╟─fcdedf52-2601-48c7-ad3b-7e74ca9aa1e6
# ╠═e46b678e-0448-4e31-a465-0a82c7380ab8
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
