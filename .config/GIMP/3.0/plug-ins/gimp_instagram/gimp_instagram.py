#!/usr/bin/env python3

'''
A complex GIMP 3 plugin that attempts to replicate the original Instagram effects. The plugin
is based on the original suite of GIMP plugins by Mario Crippa, 2013. Some simplifications and updates have been made
and the individual effects have been consolidated into a single plugin. After migrations across
different versions of GIMP, the effects have evolved away from the originals.
'''

import sys, math, gi

gi.require_version('Gegl', '0.4')
gi.require_version("Gimp", "3.0")
gi.require_version('GimpUi', '3.0')
gi.require_version('Babl', '0.1')

from gi.repository import Gimp, GLib, Babl, Gegl, GObject, GimpUi
from collections import namedtuple

#
# --- Set up names for effects---
#

effectsList = [
    ("AMARO", "Amaro"),
    ("APOLLO", "Apollo"),
    ("BRANNAN", "Brannan"),
    ("EARLYBIRD", "Earlybird"),
    ("GOTHAM", "Gotham"),
    ("INKWELL", "Inkwell"),
    ("LORDKELVIN", "Lord Kelvin"),
    ("POPROCKET", "Poprocket"),
    ("RISE", "Rise"),
    ("TOASTER", "Toaster"),
    ("VALENCIA", "Valencia"),
    ("WALDEN", "Walden")
]

# Create a Gimp.Choice for the effects, as this is the preferred way to access the values in a dialog.
# Identifier, index, label and description must be present.
Effects = Gimp.Choice.new()

for index, (identifier, label) in enumerate(effectsList):
	description = f"Apply the {label} effect"
	Effects.add(identifier, index, label, description)

#
# --- Set up names and descriptive labels for layers and vignettes ---
#

def CreateOptions(name, pairs):
    symbols = [s for s, _ in pairs]
    labels = [l for _, l in pairs]
    labelTuples = [(l, i) for i, (_, l) in enumerate(pairs)]
    reverse = {l: i for i, (_, l) in enumerate(pairs)}

    optsclass = namedtuple(name + 'Type',
                           symbols + ['labels', 'labelTuples', 'reverse'])

    return optsclass(*(list(range(len(pairs))) + [labels, labelTuples, reverse]))

Layers = CreateOptions('Layers',
					   [('LAYER1', 'Layer 1'),
		 				('LAYER2', 'Layer 2'),
						('LAYER3', 'Layer 3'),
						('VIGNETTE','Vignette'),
						('COLOR', 'Color'),
						('NOISE', 'Noise'),
						('BW', 'Black and White'),
						('GRADIENT', 'Gradient'),
						('MASK', 'Mask'),
						('MERGED', 'Merged')
])

Vignettes = CreateOptions('Vignettes',
						  [('STANDARD', 'Fits inside the image'),
							('LARGE', 'Extends outside the image'),
							('OBLATE', 'Flattened'),
							('NONE', 'Defaults to an empty layer')
])

class Instagram(Gimp.PlugIn):
	def do_query_procedures(self):
		return ["instagram"]

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
		proc.set_menu_label("Instagram")
		proc.add_menu_path("<Image>/Filters/Simon")
		proc.set_documentation("Adds the selected Instagram effect",
                            	"Applies the selected Instagram filter effect to the entire visible image.",
                                name)
		proc.set_attribution("Simon Bland", "copyright Simon Bland", "2025")

		proc.add_choice_argument("effect",
						   		"Effect type",
								"The Instagram style effect to be applied to the image.",
								Effects,
								"AMARO",
								GObject.ParamFlags.READWRITE)
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
			GimpUi.init('instagram')

			dialog = GimpUi.ProcedureDialog(procedure=procedure, config=config)
			dialog.fill(['effect'])

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
		effect = config.get_property('effect')

		#
		# --- Base code used for all effects ---
		#

		# Create group and a layer that acts as the base image for effects
		eName = Gimp.Choice.get_label(Effects, effect)
		groupName = eName + " Group"
		layerGroup = Gimp.GroupLayer.new(image, groupName)
		Gimp.Image.insert_layer(image, layerGroup, None, 0)

		layer1 = self.AddLayerFromVisible(image, layerGroup, Layers.LAYER1)

		# Calculate image dimensions and some common coordinates
		Gimp.Selection.all(image)
		sel_size = Gimp.Selection.bounds(image)
		w = sel_size.x2 - sel_size.x1
		h = sel_size.y2 - sel_size.y1
		
		originX = 0
		originY = 0
		centerX = w / 2
		centerY = h / 2
		insideX = 0.95 * w
		outsideX = 1.50 * w
		edgeX = w

		#
		# --- Individual effects ---
		#

		if effect == "AMARO":
			#adjust curves colors in non-linear space then create vignette
			self.SRGBCurvesSpline(layer1, Gimp.HistogramChannel.RED, [0, 30/255, 156/255, 196/255, 205/255, 203/255, 255/255, 255/255])
			self.SRGBCurvesSpline(layer1, Gimp.HistogramChannel.GREEN, [0, 0, 61/255, 67/255, 139/255, 184/255, 200/255, 206/255, 1.0, 1.0])
			self.SRGBCurvesSpline(layer1, Gimp.HistogramChannel.BLUE, [0, 20/255, 146/255, 184/255, 220/255, 222/255, 1.0, 1.0])
			
			#effect added to GIMP 3 version
			self.ColorToAlpha(layer1, 0.0, 0.78)

			self.CreateVignette(image, layerGroup, w, h, Vignettes.STANDARD, 60)
		
		elif effect == "APOLLO":
			#copy image black and white then add vignette and green layer
			self.AddLayerFromDrawable(drawable, image, layerGroup, Layers.BW, Gimp.LayerMode.NORMAL, True, 50)
			self.CreateVignette(image, layerGroup, w, h, Vignettes.LARGE, 40)
			self.AddColorLayer(image, Layers.COLOR, layerGroup, w, h, 50, Gimp.LayerMode.OVERLAY, 0.243, 0.804, 0.165)
		
		elif effect == "BRANNAN":
			#copy image set to overlay and desaturate then adjust hue/saturation
			layer2 = self.AddLayerFromDrawable(drawable, image, layerGroup, Layers.LAYER2, Gimp.LayerMode.OVERLAY, True, 37)
			layer2.hue_saturation(Gimp.HueRange.ALL, 0, 0, -30, 0)
			
			#select second layer copy and merge down
			mergeLayer = image.merge_down(layer2, Gimp.MergeType.CLIP_TO_IMAGE)
			mergeLayer.set_name(Layers.labels[Layers.MERGED])
			
			#adjust levels colors and brightness/contrast in the merged layer
			mergeLayer.levels(Gimp.HistogramChannel.VALUE, 0, 1.0, True, 1.0, 9/255, 1.0, True)
			mergeLayer.levels(Gimp.HistogramChannel.RED, 0, 228/255, True, 1.0, 23/255, 1.0, True)
			mergeLayer.levels(Gimp.HistogramChannel.GREEN, 0, 1.0, True, 1.0, 3/255, 1.0, True)
			mergeLayer.levels(Gimp.HistogramChannel.BLUE, 0, 239/255, True, 1.0, 12/255, 1.0, True)
			mergeLayer.brightness_contrast(-8/100, 25/100)
			
			#adjust levels colors and brightness/contrast (again)
			mergeLayer.levels(Gimp.HistogramChannel.VALUE, 0, 1.0, True, 0.91, 7/255, 1.0, True)
			mergeLayer.levels(Gimp.HistogramChannel.RED, 0, 1.0, True, 1.0, 9/255, 1.0, True)
			mergeLayer.levels(Gimp.HistogramChannel.GREEN, 0, 224/255, True, 1.0, 3/255, 1.0, True)
			mergeLayer.levels(Gimp.HistogramChannel.BLUE, 0, 1.0, True, 0.94, 18/255, 1.0, True)
			mergeLayer.brightness_contrast(-4/100, -15/100)

			#changed opacity of the layer in this version
			mergeLayer.set_opacity(40)
			
			#add new color layer in multiply mode. Color and opacity have been changed in this version.
			self.AddColorLayer(image, Layers.COLOR, layerGroup, w, h, 35, Gimp.LayerMode.MULTIPLY, 0.99, 0.830, 0.480)
		
		elif effect == "EARLYBIRD":
			#adjust hue, saturation, lightness, colors and brightness/contrast
			layer1.hue_saturation(Gimp.HueRange.ALL, 0, 1, -30, 0)
			layer1.levels(Gimp.HistogramChannel.VALUE, 0, 1.0, True, 1.2, 0, 1.0, True)
			layer1.levels(Gimp.HistogramChannel.RED, 0, 1.0, True, 1.0, 25/255, 1.0, True)
			layer1.brightness_contrast(8/100, 20/100)
			
			#adjust hue, saturation and lightness (again)
			layer1.hue_saturation(Gimp.HueRange.ALL, 0, 0, -15, 0)
			layer1.levels(Gimp.HistogramChannel.VALUE, 0, 235/255, True, 0.9, 0, 1.0, True)
				
			#add new color layer in multiply mode then add color vignette in normal mode
			self.AddColorLayer(image, Layers.COLOR, layerGroup, w, h, 100, Gimp.LayerMode.MULTIPLY, 1.0, 240/255, 205/255)
			self.CreateVignette(image, layerGroup, w, h, Vignettes.STANDARD, 6, Gimp.LayerMode.NORMAL, 0.722, 0.722, 0.722)
			
		elif effect == "GOTHAM":
			#desaturate base image
			layer1.desaturate(Gimp.DesaturateMode.LIGHTNESS)
			
			#copy image in hard light mode and adjust color curves
			layer2 = self.AddLayerFromDrawable(drawable, image, layerGroup, Layers.LAYER2, Gimp.LayerMode.HARDLIGHT)
			self.SRGBCurvesSpline(layer2, Gimp.HistogramChannel.BLUE, [0, 0, 63/255, 98/255, 128/255, 128/255, 189/255, 159/255, 1.0, 1.0])
			
			#add new layer in screen mode then add blur and noise
			layer3 = self.AddLayerFromDrawable(drawable, image, layerGroup, Layers.LAYER3, Gimp.LayerMode.SCREEN, False, 75)
			
			# Apply a motion blur and RGB noise effects
			self.AddMBlur(layer3)
			self.AddNoise(layer3)

		elif effect == "INKWELL":
			#desaturate, adjust color curves and brightness/contrast
			layer1.desaturate(Gimp.DesaturateMode.LIGHTNESS)
			self.SRGBCurvesSpline(layer1, Gimp.HistogramChannel.VALUE, [0.0, 0.0, 0.051, 0.0, 0.325, 0.490, 0.698, 0.859, 1.0, 1.0])
			layer1.brightness_contrast(-0.15, 0.15)
		
		elif effect == "LORDKELVIN":
			#adjust color curves
			self.SRGBCurvesSpline(layer1, Gimp.HistogramChannel.VALUE, [10/255, 0, 1.0, 1.0])
			self.SRGBCurvesSpline(layer1, Gimp.HistogramChannel.RED, [0, 63/255, 100/255, 200/255, 1.0, 1.0])
			self.SRGBCurvesSpline(layer1, Gimp.HistogramChannel.GREEN, [0, 30/255, 180/255, 190/255, 1.0, 210/255])
			self.SRGBCurvesSpline(layer1, Gimp.HistogramChannel.BLUE, [0, 90/255, 177/255, 114/255, 1.0, 188/255])
		
		elif effect == "POPROCKET":
			#add color1 in screen mode and set color gradient
			color1 = self.CreateVignette(image, layerGroup, w, h, Vignettes.NONE, 100, Gimp.LayerMode.SCREEN)
			self.SetContexts(Gimp.LayerMode.NORMAL, False, 0.900, 0.153, 0.274)
			color1.edit_gradient_fill(Gimp.GradientType.RADIAL, 0, False, 1, 0, True, centerX, centerY, insideX, centerY)
			
			#added to the GIMP 3 version
			self.ColorToAlpha(color1, 0.0, 1.0)
					
			#add color2 in overlay mode and set color gradient
			color2 = self.CreateVignette(image, layerGroup, w, h, Vignettes.NONE, 100, Gimp.LayerMode.SOFTLIGHT)
			self.SetContexts(Gimp.LayerMode.OVERLAY, True, 0.059, 0.019, 0.180)
			color2.edit_gradient_fill(Gimp.GradientType.RADIAL, 0, False, 1, 0, True, centerX, centerY, outsideX, centerY)

		elif effect == "RISE":
			#adjust hue saturation and levels
			layer1.hue_saturation(Gimp.HueRange.ALL, 20, 0, -50, 0)
			layer1.levels(Gimp.HistogramChannel.VALUE, 0, 1.0, True, 1.23, 0, 1.0, True)
			
			#add vignette layer in overlay mode
			vignette = self.CreateVignette(image, layerGroup, w, h, Vignettes.OBLATE, 100, Gimp.LayerMode.OVERLAY)

			#set color gradient
			self.SetContexts(Gimp.LayerMode.OVERLAY)
			vignette.edit_gradient_fill(Gimp.GradientType.RADIAL, 0, False, 1, 0, True, centerX, centerY, outsideX, centerY)
			Gimp.Selection.none(image)
		
			#add new noise layer in screen mode with opacity 20
			noiseLayer = self.AddColorLayer(image, Layers.NOISE, layerGroup, w, h, 20, Gimp.LayerMode.SCREEN, 0, 0, 0)
			self.AddNoise(noiseLayer)
				
			#add new color layer in overlay mode
			self.AddColorLayer(image, Layers.COLOR, layerGroup, w, h, 50, Gimp.LayerMode.OVERLAY, 0.929, 0.541, 0)
		
		elif effect == "TOASTER":
			#add new layer and adjust color curves
			layer2 = self.AddLayerFromDrawable(drawable, image, layerGroup, Layers.LAYER2)
			self.SRGBCurvesSpline(layer2, Gimp.HistogramChannel.VALUE, [25/255, 0, 1.0, 1.0])
			
			#add white mask to layer and create black filled ellipse
			layer2Mask = self.AddMask(layer2, 0)
			self.SelectEllipse(image, w, h, Vignettes.STANDARD)
			self.AddFill(image, layer2Mask)
			
			#gradient layer in normal mode, with fg and bg colors set
			gradient = self.AddLayerFromDrawable(drawable, image, layerGroup, Layers.GRADIENT, Gimp.LayerMode.NORMAL, False, 70)
			self.SetContexts(Gimp.LayerMode.NORMAL, False, 0.227, 0.040, 0.349, 30, False, 0.995, 0.663, 0.341)
			gradient.edit_gradient_fill(1, 0, False, 1, 0, True, originX, centerY, edgeX, centerY)
			
			#add new color layer in screen mode
			layer3 = self.AddColorLayer(image, Layers.LAYER3, layerGroup, w, h, 35, Gimp.LayerMode.SCREEN, 0.114, 0.114, 0.114)
			
			#add black mask to layer and create white filled ellipse
			layer3Mask = self.AddMask(layer3, 1)
			self.SelectEllipse(image, w, h, Vignettes.LARGE)	
			self.AddFill(image, layer3Mask, Gimp.LayerMode.NORMAL, 1.0, 1.0, 1.0)
			
			#color layer in dodge mode with mask
			color1 = self.AddColorLayer(image, Layers.COLOR, layerGroup, w, h, 1, Gimp.LayerMode.DODGE, 0.823, 0.6, 0.003)
			
			#add black mask to layer and create white filled ellipse
			color1Mask = self.AddMask(color1, 1)
			self.SelectEllipse(image, w, h, Vignettes.LARGE)
			self.AddFill(image, color1Mask, Gimp.LayerMode.NORMAL, 1.0, 1.0, 1.0)
			
		elif effect == "VALENCIA":
			#add new layer in multiply mode
			color1 = self.AddColorLayer(image, Layers.COLOR, layerGroup, w, h, 100, Gimp.LayerMode.MULTIPLY, 0.965, 0.867, 0.678)
			
			#merge down then adjust color curves and levels
			mergeLayer = image.merge_down(color1, Gimp.MergeType.CLIP_TO_IMAGE)
			self.SRGBCurvesSpline(mergeLayer, Gimp.HistogramChannel.VALUE, [0, 50/255, 75/255, 110/255, 175/255, 220/255, 1.0, 1.0])
			mergeLayer.levels(Gimp.HistogramChannel.BLUE, 0, 1.0, True, 1.0, 126/255, 1.0, True)
			self.ColorToAlpha(mergeLayer, 0.0, 0.78)
		
		elif effect == "WALDEN":
			#adjust color curves
			self.SRGBCurvesSpline(layer1, Gimp.HistogramChannel.VALUE, [12/255, 0, 1.0, 1.0])
			self.SRGBCurvesSpline(layer1, Gimp.HistogramChannel.RED, [10/255, 0, 247/255, 1.0])
			self.SRGBCurvesSpline(layer1, Gimp.HistogramChannel.BLUE, [0, 38/255, 1.0, 203/255])

			#adjust levels and color curves (again)
			layer1.levels(Gimp.HistogramChannel.VALUE, 0, 235/255, True, 1.17, 55/255, 1.0, True)
			self.SRGBCurvesSpline(layer1, Gimp.HistogramChannel.VALUE, [41/255, 0, 125/255, 124/255, 1.0, 1.0])
			
			#create new layer in soft light mode
			gradient = self.AddLayer(image, layerGroup, w, h, Layers.GRADIENT, 80, Gimp.LayerMode.SOFTLIGHT)
			
			#set contexts and apply gradient in soft light mode starting from top left
			self.SetContexts(45, False, 1.0, 1.0, 1.0)
			gradient.edit_gradient_fill(Gimp.GradientType.RADIAL, 0, False, 1, 0, True, originX, originY, centerX, centerY)
			
		# Restore context and close the undo group
		Gimp.displays_flush()
		Gimp.context_pop()
		image.undo_group_end()

		# Close Gegl
		Gegl.exit()

		return procedure.new_return_values(Gimp.PDBStatusType.SUCCESS, GLib.Error())	

	#
    # --- Methods invoking Gegl operations and PDB plugins ----
    #

	def ColorToAlpha(self, layer, transpThresh = 0.0, opacityThresh = 1.0, r = 1.0, g = 1.0, b = 1.0):
		# Add color for effect
		fgColor = Gegl.Color.new('white')
		fgColor.set_rgba(r, g, b, 0.0)

		filter = Gimp.DrawableFilter.new(layer, "gegl:color-to-alpha", "Color to Alpha")
		filter.set_blend_mode(Gimp.LayerMode.REPLACE)
		filter.set_opacity(100)
		config = filter.get_config()
		config.set_property('color', fgColor)
		config.set_property('transparency-threshold', transpThresh)
		config.set_property('opacity-threshold', opacityThresh)
		filter.update()
		layer.append_filter(filter)
		return

	#adds a linear motion blur with default settings
	def AddMBlur(self, layer):
		# Adapted from pdb.plug_in_mblur(image, layer3, 0, 256, 0, 0, 0) where type (0=LINEAR)
		filter = Gimp.DrawableFilter.new(layer, "gegl:motion-blur-linear", "Motion blur")
		filter.set_blend_mode(Gimp.LayerMode.NORMAL)
		filter.set_opacity(100)
		config = filter.get_config()
		config.set_property('length', 256)
		config.set_property('angle', 0)
		filter.update()
		layer.append_filter(filter)
		return

	#adds a noise filter with default settings
	def AddNoise(self, layer):
		# Adapted from:  pdb.plug_in_rgb_noise(image, layer3, 0, 1, 0.10, 0.10, 0.10, 0)
		filter = Gimp.DrawableFilter.new(layer, "gegl:noise-rgb", "Noise RGB")
		filter.set_blend_mode(Gimp.LayerMode.NORMAL)
		filter.set_opacity(100)
		config = filter.get_config()
		config.set_property('correlated', False)
		config.set_property('independent', False)
		config.set_property('linear', True)
		config.set_property('gaussian', True)
		config.set_property('red', 0.10)
		config.set_property('alpha', 0)
		filter.update()
		layer.append_filter(filter)
		return

    #
    # --- Utility methods and functions ----
    #

	#adds a layer with solid color fill in selected mode
	def AddColorLayer(self, image, name, layerGroup, w, h, opacity, mode, r, g, b):
		layer = self.AddLayer(image, layerGroup, w, h, name, opacity, mode)
		self.AddFill(image, layer, mode, r, g, b)
		
		return layer

	#adds a fill in specified mode and color (defaults to BLACK)
	def AddFill(self, image, layer, mode = Gimp.LayerMode.NORMAL, r = 0.0, g = 0.0, b = 0.0):
		self.SetContexts(mode, False, r, g, b)
		layer.edit_fill(Gimp.FillType.FOREGROUND)
		Gimp.Selection.none(image)
		return

	#adds a new layer with transparent fill
	def AddLayer(self, image, layerGroup, w, h, name, opacity = 100, mode = Gimp.LayerMode.NORMAL):
		layer = Gimp.Layer.new(image, Layers.labels[name], w, h, Gimp.ImageType.RGBA_IMAGE, opacity, mode)
		image.insert_layer(layer, layerGroup, 0)
		layer.fill(Gimp.FillType.TRANSPARENT)
		
		return layer

	#adds a new layer from the drawable in selected mode
	def AddLayerFromDrawable(self, drawable, image, layerGroup, name, mode = Gimp.LayerMode.NORMAL, desat = False, opacity = 100):
		layer = Gimp.Layer.new_from_drawable(drawable, image)
		image.insert_layer(layer, layerGroup, 0)
		layer.set_name(Layers.labels[name])
		layer.set_mode(mode)
		if desat == True:
			layer.desaturate(Gimp.DesaturateMode.VALUE)
		layer.set_opacity(opacity)

		return layer

	#adds a new layer from the visible image
	def AddLayerFromVisible(self, image, layerGroup, name):
		layer = Gimp.Layer.new_from_visible(image, image, Layers.labels[name])
		image.insert_layer(layer, layerGroup, 0)

		return layer

	#adds a layer mask - fill(0) is white, fill(1) is black
	def AddMask(self, layer, fill):
		mask = layer.create_mask(fill)
		layer.add_mask(mask)
		
		return mask
	
	#creates a vignette layer with an ellipse shape and selects the inverse area. Defaults to black vignette.
	def CreateVignette(self, image, layerGroup, w, h, type, opacity = 100, mode = Gimp.LayerMode.NORMAL, r = 0.0, g = 0.0, b = 0.0):
		layer = self.AddLayer(image, layerGroup, w, h, Layers.VIGNETTE, opacity, mode)
		image.set_selected_layers([layer, None])

		if type == Vignettes.NONE:
			return layer
		else:
			#Select an ellipse shape, invert selection and fill
			self.SelectEllipse(image, w, h, type)
			Gimp.Selection.invert(image)
			self.AddFill(image, layer, mode, r, g, b)
			
			return layer

	#selects a feathered ellipse shape
	def SelectEllipse(self, image, w, h, type):
		Gimp.Selection.none(image)
		if type == Vignettes.STANDARD:
			image.select_ellipse(Gimp.ChannelOps.ADD, 0, 0, w, h)
		elif type == Vignettes.LARGE:
			delta = 0.05 * w
			image.select_ellipse(Gimp.ChannelOps.ADD, 0 - delta, 0 - delta, w + (delta * 2), h + (delta * 2))
		elif type == Vignettes.OBLATE:
			delta = w / 6
			epsilon = 0.05 * h
			image.select_ellipse(Gimp.ChannelOps.ADD, 0 - delta, 0 + epsilon, w + delta * 2, h - epsilon * 2)
		else:
			return
		
		#standardize the feather amount
		feather = 0.20 * max(w, h)	
		Gimp.Selection.feather(image, feather)
		return

	#sets contexts. Settings for all fills and gradients flow though here.
	def SetContexts(self, mode, reverse = False, r = 0.0, g = 0.0, b = 0.0, opacity = 100, singleColor = True, r2 = 1.0, g2 = 1.0, b2 = 1.0):
		Gimp.context_set_opacity(opacity)
		Gimp.context_set_paint_mode(mode)
		Gimp.context_set_gradient_blend_color_space(Gimp.GradientBlendColorSpace.RGB_LINEAR)
		Gimp.context_set_gradient_reverse(reverse)

		fgColor = Gegl.Color.new('black')
		bgColor = Gegl.Color.new('white')
		fgColor.set_rgba(r, g, b, 0.0)
		bgColor.set_rgba(r2, g2, b2, 0.0)

		Gimp.context_set_foreground(fgColor)
		Gimp.context_set_background(bgColor)

		Gimp.context_set_gradient_reverse(reverse)
		if singleColor == True:
			Gimp.context_set_gradient_fg_transparent()
		else:
			Gimp.context_set_gradient_fg_bg_rgb()

		return
	
	#
	# --- Methods for applying curves_spline in non-linear space ---
	#

	def SRGBCurvesSpline(self, drawable, channel, spline):
			# Build LUTs (or cache them globally)
			lin_lut, srgb_lut = self.FastSRGBLuts()
		
			# Apply sRGB -> linear LUT
			drawable.curves_explicit(channel, lin_lut)

			# Apply spline in linear space
			drawable.curves_spline(channel, spline)

			# Convert back linear -> sRGB
			drawable.curves_explicit(channel, srgb_lut)

	def FastSRGBLuts(self, samplecount=1024):
		pow = math.pow
		sc = samplecount - 1.0

		# sRGB -> linear
		linofx = [
			(x * 12.92) if x < 0.0031308
			else (1.055 * pow(x, 1.0/2.4) - 0.055)
			for x in (i / sc for i in range(samplecount))
		]

		# linear -> sRGB
		srgbofx = [
			(x / 12.92) if x < 0.04045
			else pow((x + 0.055) / 1.055, 2.4)
			for x in (i / sc for i in range(samplecount))
		]

		return linofx, srgbofx

	def ConvertSRGBToLinear(self, values, lin_lut):
		sc = len(lin_lut) - 1
		return [lin_lut[int(v * sc)] for v in values]

	def ConvertLinearToSRGB(self, values, srgb_lut):
		sc = len(srgb_lut) - 1
		return [srgb_lut[int(v * sc)] for v in values]

# Entry point
Gimp.main(Instagram.__gtype__, sys.argv)

