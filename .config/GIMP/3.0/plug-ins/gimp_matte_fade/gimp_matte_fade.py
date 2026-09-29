#!/usr/bin/env python3

'''
An intermediate GIMP 3 plugin that combines a matte effect with color gradients. The plugin
was inspired by the work of photographers including Claire Gallagher.
'''

import sys, gi

gi.require_version('Gegl', '0.4')
gi.require_version("Gimp", "3.0")
gi.require_version('GimpUi', '3.0')
gi.require_version('Babl', '0.1')

from gi.repository import Gimp, GLib, Babl, Gegl, GObject, GimpUi

#
# --- Set up names for effects---
#

gradientsList = [('Violet/Yellow', 'Violet and yellow'),
				  ('Purple/Teal', 'Purple and teal'),
				  ('Purple/Neutral', 'Purple and neutral'),
				  ('Green/Transp.', 'Green and transparent'),
				  ('Br.Orange/Transp.', 'Bright orange to transparent'),
				  ('Dk.Orange/Transp.', 'Dark orange to transparent')
]

orientList = [('vertical', "Apply up and down"),
			  ('horizontal', 'Apply side to side')
]

# Create Gimp.Choices for gradient colors and orientations
def populate_choice(choice, items):
	for index, (identifier, label) in enumerate(items):
		description = f"Apply {label} effect"
		choice.add(identifier, index, label, description)

Gradients = Gimp.Choice.new()
populate_choice(Gradients, gradientsList)

Orientations = Gimp.Choice.new()
populate_choice(Orientations, orientList)

#
# --- Matte Fade Effect Class ---
#

class MatteFade(Gimp.PlugIn):
	def do_query_procedures(self):
		return ["matte-fade"]

	def do_create_procedure(self, name):
		Gegl.init(None)
		Babl.init()

		proc = Gimp.ImageProcedure.new(
            self,
            name,
            Gimp.PDBProcType.PLUGIN,
            self.run,
            None
        )
		proc.set_image_types("*")
		proc.set_menu_label("Matte Fade")
		proc.add_menu_path("<Image>/Filters/Simon")
		proc.set_documentation("Combines a matte effect with color gradients",
                            	"Applies a matte effect and optional color gradients to the entire visible image.",
                                name)
		proc.set_attribution("Simon Bland", "copyright Simon Bland", "2026")

		proc.add_boolean_argument("useColor", "Use color gradients", "Use color gradients", True, GObject.ParamFlags.READWRITE)
		proc.add_choice_argument("colorScheme",
						   		"Gradient Colors",
								"The gradient colors to be applied to the image.",
								Gradients,
								"Violet/Yellow",
								GObject.ParamFlags.READWRITE)
		proc.add_choice_argument("orientation",
						   		"Gradient Orientation",
								"Apply gradient up and down or side to side.",
								Orientations,
								"vertical",
								GObject.ParamFlags.READWRITE)
		proc.add_boolean_argument("flipColors", "Reverse color gradients", "Reverse color gradients", False, GObject.ParamFlags.READWRITE)
		proc.add_double_argument("colorOpacity", "Gradient opacity", "Gradient opacity", 0.0, 100, 25.0, GObject.ParamFlags.READWRITE)
		proc.add_double_argument("colorOffset", "Gradient color offset", "Gradient color offset", 0.0, 100, 20.0, GObject.ParamFlags.READWRITE)
		proc.add_boolean_argument("overExposure", "Overexpose", "Overexpose", True, GObject.ParamFlags.READWRITE)
		proc.add_double_argument("oeAmount", "Overexposure amount", "Overexposure amount", 0.0, 100, 20.0, GObject.ParamFlags.READWRITE)
		proc.add_boolean_argument("addVignette", "Add vignette", "Add vignette", True, GObject.ParamFlags.READWRITE)
		proc.add_boolean_argument("addSharpen", "Add sharpening", "Add sharpening", True, GObject.ParamFlags.READWRITE)

		return proc
	
	def run(self, procedure, run_mode, image, drawables, config, data):
		Gegl.init(None)

		# Drawable
		drawable = drawables[0]

		# Start an undo group so the whole operation is one step in history, and set
		# foreground and background colors
		image.undo_group_start()
		Gimp.context_push()
		
		# Show a dialog box to capture input parameters
		if run_mode == Gimp.RunMode.INTERACTIVE:
			GimpUi.init('matte-fade')

			dialog = GimpUi.ProcedureDialog(procedure=procedure, config=config)
			dialog.fill(['useColor',
						'colorScheme',
						'orientation',
						'flipColors',
						'colorOpacity',
						'colorOffset',
						'overExposure',
						'oeAmount',
						'addVignette',
						'addSharpen'
			])

			if not dialog.run():
				dialog.destroy()

				Gimp.context_pop()
				image.undo_group_end()

				# Close Gegl
				Gegl.exit()

				return procedure.new_return_values(Gimp.PDBStatusType.CANCEL, None)
			else:
				dialog.destroy()

		# Get dialog variables
		useColor = config.get_property('useColor')
		colorScheme = config.get_property('colorScheme')
		orientation = config.get_property('orientation')
		flipColors = config.get_property('flipColors')
		colorOpacity = config.get_property('colorOpacity')
		colorOffset = config.get_property('colorOffset')
		overExposure = config.get_property('overExposure')
		oeAmount = config.get_property('oeAmount')
		addVignette = config.get_property('addVignette')
		addSharpen = config.get_property('addSharpen')

		#calculate image dimensions and some common coordinates
		Gimp.Selection.all(image)
		sel_size = Gimp.Selection.bounds(image)
		w = sel_size.x2 - sel_size.x1
		h = sel_size.y2 - sel_size.y1

		if orientation == 'vertical':
			#vertical gradient
			#set color gradient start point
			startX = w / 2
			startY = 0
		
			#set color gradient end points
			endX = w / 2
			endY = h

		else:
			#horizontal gradient
			#set color gradient start point
			startX = 0
			startY = h / 2
		
			#set color gradient end points
			endX = w
			endY = h / 2

		#set image center and corner points
		centerX = w / 2
		centerY = h / 2
		cornerX = w
		cornerY = h

		#
		# --- Adjust curves ---
		#

		#layer copy from background and use this as the starting point for processing
		copyLayer1 = Gimp.Layer.new_from_visible(image, image, "AdjustCurves")
		image.insert_layer(copyLayer1, None, -1)

		#set layer mode and opacity
		copyLayer1.set_opacity(50)
		copyLayer1.set_mode(Gimp.LayerMode.NORMAL)

		#adjust curves
		curveArray = [0.0, 23/255, 28/255, 35/255, 1.0, 1.0]
		copyLayer1.curves_spline(Gimp.HistogramChannel.VALUE, curveArray)

		#
		# --- Add sharpening ---
		#

		if addSharpen == True:

			#set other contexts for sharpen gradient.
			Gimp.context_set_opacity(50.0)
			Gimp.context_set_paint_mode(Gimp.LayerMode.NORMAL)
			Gimp.context_set_gradient_fg_bg_rgb()
			Gimp.context_set_gradient_blend_color_space(Gimp.GradientBlendColorSpace.RGB_LINEAR)
			Gimp.context_set_gradient_reverse(False)

			#set colors to black and white
			fgColor = Gegl.Color.new('white')
			bgColor = Gegl.Color.new('black')

			Gimp.context_set_foreground(fgColor)
			Gimp.context_set_background(bgColor)

			#copy the visible image for sharpening
			copyLayer6=Gimp.Layer.new_from_visible(image, image, "Sharpen")
			image.insert_layer(copyLayer6, None, -1)

			# Apply the sharpen(unsharp mask) GEGL effect. Not all settings are available.
			filter = Gimp.DrawableFilter.new(copyLayer6, "gegl:unsharp-mask", "Unsharp Mask")
			filter.set_blend_mode(Gimp.LayerMode.NORMAL)
			filter.set_opacity(100)
			config = filter.get_config()
			config.set_property('threshold', 0.0)
			filter.update()
			copyLayer6.append_filter(filter)

			#add layer mask with black fill 
			layerMask6 = copyLayer6.create_mask(Gimp.AddMaskType.BLACK)
			copyLayer6.add_mask(layerMask6)

			#apply a blend to the layer mask that fades out sharpening away from the center of the image
			sharpenOffset = 20
			layerMask6.edit_gradient_fill(Gimp.GradientType.RADIAL, sharpenOffset, False, 1, 0, True, centerX, centerY, cornerX, cornerY)

		#
		# --- Add vignette ---
		#

		if addVignette == True:

			#set other contexts for vignette gradient.
			Gimp.context_set_opacity(100)
			Gimp.context_set_paint_mode(Gimp.LayerMode.NORMAL)
			Gimp.context_set_gradient_fg_transparent()
			Gimp.context_set_gradient_blend_color_space(Gimp.GradientBlendColorSpace.RGB_LINEAR)
			Gimp.context_set_gradient_reverse(True)

			#set foreground color
			fgColor = Gegl.Color.new('black')
			
			Gimp.context_set_foreground(fgColor)

			#add a new layer for vignette
			copyLayer5=Gimp.Layer.new(image, "Vignette", w, h, Gimp.ImageType.RGBA_IMAGE, 50.0, Gimp.LayerMode.OVERLAY)
			image.insert_layer(copyLayer5, None, -2)

			#add radial gradient w/start point in center of image
			vignetteOffset = 80
			copyLayer5.edit_gradient_fill(Gimp.GradientType.RADIAL, vignetteOffset, False, 1, 0, True, centerX, centerY, cornerX, cornerY)

		#
		# --- Add color overlay ---
		#

		if useColor == True:

			#set contexts for gradient
			Gimp.context_set_opacity(colorOpacity)
			Gimp.context_set_paint_mode(Gimp.LayerMode.HSL_COLOR)
			Gimp.context_set_gradient_fg_bg_rgb()
			Gimp.context_set_gradient_blend_color_space(Gimp.GradientBlendColorSpace.RGB_LINEAR)
			Gimp.context_set_gradient_reverse(flipColors)

			#initialize some new colors for the gradients
			fgColor = Gegl.Color.new('white')
			bgColor = Gegl.Color.new('black')

			#set color contexts
			if colorScheme == 'Violet/Yellow':
				#warm colors to violet and orange
				fgColor.set_rgba(198/255, 4/255, 198/255, 0.0)
				bgColor.set_rgba(227/255, 145/255, 3/255, 0.0)

				Gimp.context_set_foreground(fgColor)
				Gimp.context_set_background(bgColor)

			elif colorScheme == 'Purple/Teal':
				#cool colors to purple and teal
				fgColor.set_rgba(124/255, 63/255, 156/255, 0.0)
				bgColor.set_rgba(10/255, 139/255, 166/255, 0.0)

				Gimp.context_set_foreground(fgColor)
				Gimp.context_set_background(bgColor)

			elif colorScheme == 'Purple/Neutral':
				#neutral colors to purple and neutral gray
				fgColor.set_rgba(124/255, 63/255, 156/255, 0.0)
				bgColor.set_rgba(189/255, 181/255, 149/255, 0.0)

				Gimp.context_set_foreground(fgColor)
				Gimp.context_set_background(bgColor)

			elif colorScheme == 'Green/Transp.':
				#green to transparent
				bgColor.set_rgba(16/255, 230/255, 3/255, 0.0)

				Gimp.context_set_gradient_fg_transparent()
				Gimp.context_set_foreground(bgColor)

			elif colorScheme == 'Br.Orange/Transp.':
				#bright orange to transparent
				bgColor.set_rgba(236/255, 180/255, 102/255, 0.0)

				Gimp.context_set_gradient_fg_transparent()
				Gimp.context_set_foreground(bgColor)

			else:
				#dark orange to transparent == 'Dk.Orange/Transp.'
				bgColor.set_rgba(178/255, 77/255, 0/255, 0.0)

				Gimp.context_set_gradient_fg_transparent()
				Gimp.context_set_foreground(bgColor)

			#create new layer and fill with transparency
			copyLayer2=Gimp.Layer.new(image, "ColorOverlay", w, h, Gimp.ImageType.RGBA_IMAGE, 50.0, Gimp.LayerMode.OVERLAY)
			image.insert_layer(copyLayer2, None, -1)
			
			#add gradient w/start point in top center of image finish in bottom center
			copyLayer2.edit_gradient_fill(Gimp.GradientType.LINEAR, colorOffset, False, 1, 0, True, startX, startY, endX, endY)

		#
		# --- Add overexposure ---
		#

		if overExposure == True:
		
			#set other contexts for overexposure gradient.
			Gimp.context_set_opacity(oeAmount)
			Gimp.context_set_paint_mode(Gimp.LayerMode.ADDITION)
			Gimp.context_set_gradient_fg_transparent()
			Gimp.context_set_gradient_blend_color_space(Gimp.GradientBlendColorSpace.RGB_LINEAR)
			Gimp.context_set_gradient_reverse(False)

			#set colors to black and white
			fgColor = Gegl.Color.new('white')
			bgColor = Gegl.Color.new('black')

			Gimp.context_set_foreground(fgColor)
			Gimp.context_set_background(bgColor)
		
			#set gradient offset to fixed amount
			oeOffset = 0

			#add and insert new layer
			copyLayer4=Gimp.Layer.new(image, "OverExposure", w, h, Gimp.ImageType.RGBA_IMAGE, 50.0, Gimp.LayerMode.HSL_COLOR)
			image.insert_layer(copyLayer4, None, -1)

			#add radial gradient w/start point in center of image finish in bottom center or center right edge
			copyLayer4.edit_gradient_fill(Gimp.GradientType.RADIAL, oeOffset, False, 1, 0, True, centerX, centerY, endX, endY)

		# Restore context and close the undo group
		Gimp.displays_flush()
		Gimp.context_pop()
		image.undo_group_end()

		# Clean up Gegl
		Gegl.exit()

		return procedure.new_return_values(Gimp.PDBStatusType.SUCCESS, None)

# Entry point
Gimp.main(MatteFade.__gtype__, sys.argv)