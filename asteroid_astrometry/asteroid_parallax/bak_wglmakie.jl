details("Makie.jl alternative",
	@mdx """
	```julia
	using WGLmakie
	set_theme!(theme_light())
	update_theme!(Heatmap=(; colormap=:cividis))
	let
		fig = Figure()
		
		ax_east, _ = plot_img!(fig[1, 1], img_east; title=OBSERVATORIES[1])
		colsize!(fig.layout, 1, Aspect(1, 1.0))
		
		ax_west, _ = plot_img!(fig[1, 2], img_west; title=OBSERVATORIES[2])
		colsize!(fig.layout, 2, Aspect(1, 1.0))
		
		linkaxes!(ax_east, ax_west)
		
		resize_to_layout!(fig)
		
		fig
	end

	function plot_img!(fig, img;
		title = "title here",
		colorrange = zscale(img),
		colorbar = true,
	)
		ax, p = image(fig[1, 1], img;
			colorrange,
			inspector_label = tooltip_hm,
			axis = (
				aspect = DataAspect(),
				# aspect = 1,
				# limits = ((0, 320), (0, 320)),
				xlabel = "X (pixels)",
				ylabel = "Y (pixels)",
				title,
			),
		)
	
		if colorbar
			Colorbar(fig[1, 2], p; label="Counts")
		end
	
		return ax, p
	end

	function tooltip_hm(self, i, pos)
		x, y, val = round.(Int, pos, RoundNearestTiesUp)
		return "H[\$(x), \$(y)] = \$(val)"
	end
	```
	"""
)

details("Makie.jl alternative",
@mdx """
```julia
fig = Figure()

i = Observable(1)
title = @lift OBSERVATORIES[\$i]
img_i = @lift imgs_stacked[\$i]
colorrange = @lift zscale(\$img_i)

plot_img!(fig, img_i; title, colorrange, colorbar=false)

fig
```

```julia
record(fig, "blink.gif", 1:2; framerate=1) do t
	i[] = t
end

LocalResource("./blink.gif")
```
"""
)


