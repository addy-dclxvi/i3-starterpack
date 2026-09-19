#!/usr/bin/env python3
# -*- coding: utf-8 -*-

'''
An intermediate GIMP 3 plugin that attempts to replicate the style of Swedish photographer Annie Nykvist. The plugin
desaturates the entire image and applies a gradated softglow effect, with a minimal white vignette and gradated sharpening.
'''

import sys, math, gi
from gi.repository import Gimp, GLib, Babl, Gegl, GObject, GimpUi

gi.require_version('Gegl', '0.4')
gi.require_version("Gimp", "3.0")
gi.require_version('GimpUi', '3.0')
gi.require_version('Babl', '0.1')

class Nykvist(Gimp.PlugIn):
    def do_query_procedures(self):
        # This is the name that appears in the procedure browser
        return ["nykvist"]

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
        proc.set_menu_label("Nykvist")
        proc.add_menu_path("<Image>/Filters/Simon")
        proc.set_documentation("Desaturates and adds a softglow effect",
                                "Desaturates and adds a softglow effect. Effect is applied to the entire visible image.",
                                name)
        proc.set_attribution("Simon Bland", "Simon Bland", "2025")

        proc.add_double_argument("brightAdjust", "Brightness", "Brightness adjustment", -0.5, 0.5, 0.4, GObject.ParamFlags.READWRITE)
        proc.add_double_argument("contrastAdjust", "Contrast", "Contrast adjustment", -0.5, 0.5, 0.3, GObject.ParamFlags.READWRITE)
        proc.add_boolean_argument("isGlow", "Glow effect", "Enable glow effect", True, GObject.ParamFlags.READWRITE)
        proc.add_boolean_argument("isSharp", "Sharpen effect", "Enable sharpen effect", True, GObject.ParamFlags.READWRITE)

        return proc

    def run(self, procedure, run_mode, image, drawable, config, data):

        Gegl.init(None)

        # Start an undo group so the whole operation is one step in history, and set
        # foreground and background colors
        image.undo_group_start()
        Gimp.context_push()

        # Set context values that will be used throughout unless overridden
        Gimp.context_set_foreground(Gegl.Color.new('white'))
        Gimp.context_set_background(Gegl.Color.new('black'))
        Gimp.context_set_paint_mode(Gimp.LayerMode.NORMAL)
        Gimp.context_set_gradient_fg_bg_rgb()
        Gimp.context_set_gradient_blend_color_space(Gimp.GradientBlendColorSpace.RGB_LINEAR)
        Gimp.context_set_opacity(100)
        Gimp.context_set_gradient_reverse(True)
 
        # Show a dialog box to capture input parameters. Do not attempt to show a dialog if called non-interactively.
        if run_mode == Gimp.RunMode.INTERACTIVE:
            GimpUi.init('nykvist')

            dialog = GimpUi.ProcedureDialog(procedure=procedure, config=config)
            dialog.fill(['brightAdjust', 'contrastAdjust', 'isGlow', 'isSharp'])

            is_ok_pressed = dialog.run()
            if not dialog.run():
                dialog.destroy()

                Gimp.context_pop()
                image.undo_group_end()

				# Close Gegl
                Gegl.exit()

                return procedure.new_return_values(Gimp.PDBStatusType.CANCEL, None)
            
            else:
                dialog.destroy()
        
        # Dialog variables
        brightAdjust = config.get_property('brightAdjust')
        contrastAdjust = config.get_property('contrastAdjust')
        isGlow = config.get_property('isGlow')
        isSharp = config.get_property('isSharp')

        # Get height and width of image
        Gimp.Selection.all(image)
        sel_size = Gimp.Selection.bounds(image)
        w = sel_size.x2 - sel_size.x1
        h = sel_size.y2 - sel_size.y1

        # Set blend start points
        startX = w / 2
        startY = h / 2
        
        # Use diagonal as basis for blend end points
        diagonal = (math.sqrt(h * h + w * w)) * 0.95
        endX = w / 2 + diagonal / 2
        endY = h / 2
        sharpenX = w / 2 + diagonal * 0.85
        sharpenY = h / 2

        # Apply effects
        baseLayer = self.apply_base_adjustments(image, brightAdjust, contrastAdjust)

        if isGlow:
            self.apply_softglow(image, baseLayer, w, startX, startY, endX, endY)
            self.apply_vignette(image, w, h, startX, startY, endX, endY)

        if isSharp:
            self.apply_sharpen(image, startX, startY, sharpenX, sharpenY)

        if dialog is not None:
            dialog.destroy()

        # Restore context and close the undo group
        Gimp.displays_flush()
        Gimp.context_pop()
        image.undo_group_end()

		# Clean up Gegl
		Gegl.exit()

        return procedure.new_return_values(Gimp.PDBStatusType.SUCCESS, GLib.Error())
    #
    # --- Effect functions ---
    #

    #desaturates the image and changes brightness and contrast
    def apply_base_adjustments(self, image, brightAdjust, contrastAdjust):
        # Add a new layer
        layer = Gimp.Layer.new_from_visible(image, image, "Desaturate")
        image.insert_layer(layer, None, -1)

        # Desaturate the layer
        layer.desaturate(Gimp.DesaturateMode.VALUE)

        # Adjust the brightness and contrast
        layer.brightness_contrast(brightAdjust, contrastAdjust)
        return layer

    #applies the Softglow effect to a new layer
    def apply_softglow(self, image, baseLayer, w, startX, startY, endX, endY):
        # Add a new layer
        glowLayer = Gimp.Layer.new_from_visible(image, image, "SoftglowBase")
        image.insert_layer(glowLayer, None, -1)

        # Apply the softglow GEGL effect
        filter = Gimp.DrawableFilter.new(glowLayer, "gegl:softglow", "Softglow")
        filter.set_blend_mode(Gimp.LayerMode.NORMAL)
        filter.set_opacity(100)
        config = filter.get_config()

        # Glow Radius has a maximum allowed size of 50 pixels
        glowRadius = w * 0.05
        if glowRadius > 50.0:
            glowRadius = 50.0 
        config.set_property('glow-radius', glowRadius)
        
        # Use presets for brightness and sharpness
        config.set_property('brightness', 0.7)
        config.set_property('sharpness', 0.5)
        filter.update()
        glowLayer.append_filter(filter)

        # Add a black layer mask
        mask = glowLayer.create_mask(Gimp.AddMaskType.BLACK)
        glowLayer.add_mask(mask)

		# Add radial gradient w/start point in center of mask to control softglow visibility
        Gimp.context_set_opacity(70)
        glowOffset = 10
        
        mask.edit_gradient_fill(Gimp.GradientType.RADIAL, glowOffset, False, 0, 0, False, startX, startY, endX, endY)

        # Create layers to subtract and add softglow effects
        subtractLayer = baseLayer.copy()
        image.insert_layer(subtractLayer, None, -1)
        subtractLayer.set_name("SoftglowSubtract")
        subtractLayer.set_mode(Gimp.LayerMode.SUBTRACT)

        addLayer = Gimp.Layer.new_from_visible(image, image, "SoftglowAdd")
        image.insert_layer(addLayer, None, -1)
        addLayer.set_mode(Gimp.LayerMode.ADDITION)

        # Modify layer visibilities
        glowLayer.set_visible(False)
        subtractLayer.set_visible(False)

    #adds a new layer with white vignette
    def apply_vignette(self, image, w, h, startX, startY, endX, endY):
        # Add a new layer with white fill - note the LayerMode type
        vignette = Gimp.Layer.new(image, "Vignette", w, h, Gimp.ImageType.RGB_IMAGE, 1, Gimp.LayerMode.OVERLAY)
        image.insert_layer(vignette, None, -2)
        vignette.fill(Gimp.FillType.WHITE)
        vignette.set_opacity(35)

        # add radial gradient to create vignette effect
        Gimp.context_set_opacity(100)
        vignetteOffset = 80

        vignette.edit_gradient_fill(Gimp.GradientType.RADIAL, vignetteOffset, False, 0, 0, False, startX, startY, endX, endY)

    #adds a new layer with gradated sharpening effect
    def apply_sharpen(self, image, startX, startY, sharpenX, sharpenY):
        # Add a new layer on which to apply the sharpen effect
        sharpenLayer = Gimp.Layer.new_from_visible(image, image, "Sharpen")
        image.insert_layer(sharpenLayer, None, -1)
        sharpenLayer.set_opacity(100)

        # Apply the sharpen(unsharp mask) GEGL effect. Not all settings are available.
        filter = Gimp.DrawableFilter.new(sharpenLayer, "gegl:unsharp-mask", "Unsharp Mask")
        filter.set_blend_mode(Gimp.LayerMode.NORMAL)
        filter.set_opacity(100)
        config = filter.get_config()
        config.set_property('threshold', 0.0)
        filter.update()
        sharpenLayer.append_filter(filter)

        # Add a black mask to sharpen layer
        mask = Gimp.Layer.create_mask(sharpenLayer, Gimp.AddMaskType.BLACK)
        sharpenLayer.add_mask(mask)

        # Apply a gradient that fades out sharpening away from the center of the image
        Gimp.context_set_opacity(100)
        Gimp.context_set_gradient_reverse(False)
        offset = 0.5

        mask.edit_gradient_fill( Gimp.GradientType.RADIAL, offset, False, 0, 0, False, startX, startY, sharpenX, sharpenY)

# Entry point
Gimp.main(Nykvist.__gtype__, sys.argv)
