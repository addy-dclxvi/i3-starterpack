#!/usr/bin/env python3

# --- Parts of this text description were taken from the original script file. Updates added at bottom ---
#
#   This program is free software  you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation  either version 2 of the License, or
#   (at your option) any later version.
#   
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY  without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#   
#   Copyright (C) 2005 Francois Le Lay <mfworx@gmail.com>
#  
#   October 23, 2007
#   Script made GIMP 2.4 compatible by Donncha O Caoimh, donncha@inphotos.org
#   Download at http://inphotos.org/gimp-lomo-plugin/
#
#   Updated by elsamuko <elsamuko@web.de>
#   http://registry.gimp.org/node/7870
#  
#   January 29, 2024
#   Script made 2.10 compatible by Simon Bland portraitsbysimonbland.com
#   Download at https://github.com/Nikkinoodl/Lomo/blob/main/2.10/pbsb-lomo.scm
#
#   January 10, 2026
#   Script converted to GIMP 3.0 Python plugin by Simon Bland portraitsbysimonbland.com.
#   New color effects were added.
#   Basic effects are now done via non-destructive Gegl operations and
#   the order of operations has been changed. Default values and ranges for each have changed.
#
#   All vignetting is now performed by the gegl:vignette operation.
#
#   As before, double and black vignetting are performed in additional layers however changes have been made to both
#   operations. Change the layer opacity of each to modify their strength.
#
#   The curves_spline and LAB operations take place in linear light, vs the perceptual space that was used in Gimp 2.10
#   and earlier versions (LAB inversions are unchanged). These operations have been modified from the original plugin
#   to give better results.
#   Download at https://github.com/Nikkinoodl/Lomo/blob/main/3.0/gimp_lomo/gimp_lomo.py

'''
A complex GIMP 3 plugin that combines multiple effects to recreate the feel of retro, analog photography. Adapted from
the original version, simplified, converted to Gimp 3 Python and modified to use Gegl operations.
'''

import sys, math, gi

gi.require_version('Gegl', '0.4')
gi.require_version("Gimp", "3.0")
gi.require_version('GimpUi', '3.0')
gi.require_version('Babl', '0.1')

from gi.repository import Gimp, GLib, Babl, Gegl, GObject, GimpUi

# Set up the color modification options
colorList = [("Neutral", "Neutral", "Leaves the color unchanged"),
            ("Old Red", "Old Red", "Applies a vintage red effect"),
            ("XPro Green", "XPro Green", "Applies a cross-processed effect that shifts blues towards green"),
            ("Blue", "Blue", "Applies a blue cast to the entire image"),
            ("XPro Autumn", "XPro Autumn", "Applies a cross-processed effect with an autumnal feel"),
            ("Movie", "Movie", "Applies a color effect that simulates retro movie colors"),
            ("Vintage", "Vintage", "Applies a vintage photo color effect"),
            ("XPro LAB", "XPro LAB", "Stretches the values of the decomposed A and B channels and recomposes the image"),
            ("Light Blue", "Light Blue", "Renders the image in a light blue palette"),
            ("Tokina Lens", "Tokina Lens", "Emulates the blue/green color characteristics of an old Tokina lens"),
            ("Redscale", "Redscale", "Converts the image to a red palette"),
            ("Retro B/W", "Retro B/W", "Applies an old-time black and white effect"),
            ("Paynes B/W", "Paynes B/W", "Applies a blue-gray black and white effect"),
            ("Sepia", "Sepia", "Renders the image in sepia tones")
]

invertList = [("None", "None", "No LAB inversion is applied"),
              ("InvertA", "Invert A", "Inverts the LAB A channel"),
              ("InvertB", "Invert B", "Inverts the LAB B channel")
]

# Create Gimp.Choices for color options. Note: will not work without identifier, index, label and description.
def populate_choice(choice, items):
  for index, (identifier, label, description) in enumerate(items):
    choice.add(identifier, index, label, description)

Colors = Gimp.Choice.new()
populate_choice(Colors, colorList)

Inversions = Gimp.Choice.new()
populate_choice(Inversions, invertList)

class Lomo(Gimp.PlugIn):
  def do_query_procedures(self):
    return ["lomo"]
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
    proc.set_menu_label("Lomo")
    proc.add_menu_path("<Image>/Filters/Simon")
    proc.set_documentation("Applies multiple effects to recreate the feel of Lomo photography",
                          "Applies multiple effects to the entire visible image to recreate the feel of Lomo photography. " \
                          "Latest version can be downloaded from https://github.com/Nikkinoodl/Lomo/3.0/gimp_lomo.py ",
                          name)
    proc.set_attribution("Simon Bland", "copyright Simon Bland", "2026")
    proc.add_double_argument("saturation", "Saturation", "Saturation", 1, 2, 1, GObject.ParamFlags.READWRITE)
    proc.add_double_argument("contrast", "Contrast", "Contrast", 1, 2, 1.1, GObject.ParamFlags.READWRITE)
    proc.add_double_argument("wideAngle", "Wide Angle Distortion", "Wide angle distortion", 0, 100, 25, GObject.ParamFlags.READWRITE)
    proc.add_double_argument("lensBlur", "Lens Blur", "Overall lens focusing blur", 0, 10, 3, GObject.ParamFlags.READWRITE)
    proc.add_double_argument("edgeBlur", "Edge Blur", "Extra edge and corner blur", 0, 20, 12, GObject.ParamFlags.READWRITE)
    proc.add_boolean_argument("grain", "Grain", "Grain", True, GObject.ParamFlags.READWRITE)
    proc.add_boolean_argument("sharpness", "Sharpness", "Sharpness", True, GObject.ParamFlags.READWRITE)
    proc.add_boolean_argument("overExposure", "Overexposure", "Add a layer that simulates overexposure in the center ofthe image", True, GObject.ParamFlags.READWRITE)
    proc.add_choice_argument("colorScheme", "Color Scheme", "The color theme to be applied to the image", Colors, "Neutral", GObject.ParamFlags.READWRITE)
    proc.add_choice_argument("inversion", "Invert LAB A/B", "Apply an inversion to a LAB channel", Inversions, "None", GObject.ParamFlags.READWRITE)
    proc.add_double_argument("vignetteSize", "Vignette Size", "Size of the vignette as a proportion of the image radial", 0.0, 2.0, 1.417, GObject.ParamFlags.READWRITE)
    proc.add_boolean_argument("dblVignette", "Extra Vignette", "Apply an extra layer of fixed vignette", True, GObject.ParamFlags.READWRITE)
    proc.add_boolean_argument("blackVignette", "Dark Vignette", "Apply an editable, opaque dark vignette", True, GObject.ParamFlags.READWRITE)
    proc.add_double_argument("blkVignette", "Dark Vig Size", "Size of the dark vignette as a proportion of the image radial", 0.0, 2.0, 1.417, GObject.ParamFlags.READWRITE)                  

    return proc

  def run(self, procedure, run_mode, image, drawables, config, data):
    Gegl.init(None)
    Babl.init()

    # Get drawable and convert image type if needed
    drawable = drawables[0]
    
    if drawable.is_gray():
      image.convert_rgb()

    # Start an undo group so the whole operation is one step in history
    image.undo_group_start()
    Gimp.context_push()
    
    # Show a dialog box to capture input parameters
    if run_mode == Gimp.RunMode.INTERACTIVE:
      GimpUi.init('lomodev')

      dialog = GimpUi.ProcedureDialog(procedure=procedure, config=config)
      dialog.fill(['saturation',
                  'contrast',
                  'wideAngle',
                  'lensBlur',
                  'edgeBlur',
                  'grain',
                  'sharpness',
                  'overExposure',
                  'colorScheme',
                  'inversion',
                  'vignetteSize',
                  'dblVignette',
                  'blackVignette',
                  'blkVignette'
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
    saturation = config.get_property('saturation')
    contrast = config.get_property('contrast')
    wideAngle = config.get_property('wideAngle')
    lensBlur = config.get_property('lensBlur')
    edgeBlur = config.get_property('edgeBlur')
    grain = config.get_property('grain')
    sharpness = config.get_property('sharpness')
    overExposure = config.get_property('overExposure')
    colorScheme = config.get_property('colorScheme')
    inversion = config.get_property('inversion')
    vignetteSize = config.get_property('vignetteSize')
    dblVignette = config.get_property('dblVignette')
    blackVignette = config.get_property('blackVignette')
    blkVignette = config.get_property('blkVignette')

    #
    # --- Calculate image dimensions, some common coordinates and basic settings ---
    #

    Gimp.Selection.all(image)
    sel_size = Gimp.Selection.bounds(image)
    w = sel_size.x2 - sel_size.x1
    h = sel_size.y2 - sel_size.y1
    centerX = w / 2
    centerY = h / 2

    self.SetDefaultContexts()
    offset = 0

    #
    # --- Base layer and effects ----
    #

    # Starting point for the effects
    # optionally use:  baseLayer = Gimp.Layer.new_from_drawable(drawable, image)
    baseLayer = self.AddLayerFromVisible(image, "Base Effects")

    # Add basic effects. DrawableFilter is used instead of Gegl graph so that the filters can
    # be applied non-destructively
    self.SetContrast(baseLayer, contrast)
    self.SetSaturation(baseLayer, saturation)
    self.LensDistortion(baseLayer, wideAngle)

    if lensBlur > 0:
      self.GaussianBlur(baseLayer, lensBlur)  # Gaussian blur instead of gegl:lens-blur plugin as it cannot be used non-destructively
      # self.apply_softglow(image, baseLayer, w, centerX, centerY)

    if edgeBlur > 0:
      self.EdgeBlur(baseLayer, edgeBlur)  # Focus blur to create fuzziness in the corners and edges of the image

    if sharpness == True:
      self.UnsharpMask(baseLayer)
 
    #
    # --- Color effects ---
    #

    # Because some color effects duplicate existing layers, it is better to apply these after
    # any distortion or blur effects
    match colorScheme:
      case "Old Red": #rom djinn (http://registry.gimp.org/node/4683)
        self.sRGBCurvesSpline(baseLayer, Gimp.HistogramChannel.VALUE, [0, 0, 68/255, 64/255, 190/255, 219/255, 1.0, 1.0])
        self.sRGBCurvesSpline(baseLayer, Gimp.HistogramChannel.RED, [0, 0, 39/255, 93/255, 193/255, 147/255, 1.0, 1.0])
        self.sRGBCurvesSpline(baseLayer, Gimp.HistogramChannel.GREEN, [0, 0, 68/255, 70/255, 1.0, 207/255])
        self.sRGBCurvesSpline(baseLayer, Gimp.HistogramChannel.BLUE, [0, 0, 94/255, 94/255, 255/255, 199/255])

      case "XPro Green": #from lilahpops (http://www.lilahpops.com/cross-processing-with-the-gimp/)
        self.sRGBCurvesSpline(baseLayer, Gimp.HistogramChannel.RED, [0, 0, 80/255, 84/255, 149/255, 192/255, 191/255, 248/255, 1.0, 1.0])
        self.sRGBCurvesSpline(baseLayer, Gimp.HistogramChannel.GREEN, [0, 0, 70/255, 81/255, 159/255, 220/255, 1.0, 1.0])
        self.sRGBCurvesSpline(baseLayer, Gimp.HistogramChannel.BLUE, [0, 27/255, 1.0, 213/255])

      case "Blue":
        self.sRGBCurvesSpline(baseLayer, Gimp.HistogramChannel.RED, [0, 62/255, 1.0, 229/255])
        self.sRGBCurvesSpline(baseLayer, Gimp.HistogramChannel.GREEN, [0, 0, 69/255, 29/255, 193/255, 240/255, 1.0, 1.0])
        self.sRGBCurvesSpline(baseLayer, Gimp.HistogramChannel.BLUE, [0, 27/255, 82/255, 44/255, 202/255, 241/255, 1.0, 1.0])
    
      case "XPro Autumn":
        self.sRGBCurvesSpline(baseLayer, Gimp.HistogramChannel.RED, [0, 0, 90/255, 150/255, 240/255, 1.0])
        self.sRGBCurvesSpline(baseLayer, Gimp.HistogramChannel.GREEN, [0, 0, 136/255, 107/255, 240/255, 1.0])
        self.sRGBCurvesSpline(baseLayer, Gimp.HistogramChannel.BLUE, [0, 0, 136/255, 107/255, 1.0, 246/255])

      case "Movie": #from http://tutorials.lombergar.com/achieve_the_indie_movie_look.html
        self.sRGBCurvesSpline(baseLayer, Gimp.HistogramChannel.VALUE, [40/255, 0, 1.0, 1.0])
        self.sRGBCurvesSpline(baseLayer, Gimp.HistogramChannel.RED, [0, 0, 127/255, 157/255, 1.0, 1.0])
        self.sRGBCurvesSpline(baseLayer, Gimp.HistogramChannel.GREEN, [0, 8/255, 1.0, 1.0])
        self.sRGBCurvesSpline(baseLayer, Gimp.HistogramChannel.BLUE, [0, 0, 127/255, 106/255, 1.0, 245/255])

      case "Vintage": #from mm1 (http://registry.gimp.org/node/1348)
        yellowLayer = self.AddLayer(image, "Yellow", w, h, 59, Gimp.LayerMode.MULTIPLY)
        self.FillWithColor(yellowLayer, 251/255, 242/255, 163/255)

        magentaLayer = self.AddLayer(image, "Magenta", w, h, 20, Gimp.LayerMode.SCREEN)
        self.FillWithColor(magentaLayer, 232/255, 101/255, 179/255)

        cyanLayer = self.AddLayer(image, "Cyan", w, h, 17, Gimp.LayerMode.SCREEN)
        self.FillWithColor(cyanLayer, 9/255, 73/255, 233/255)

      case "XPro LAB": #LAB from Martin Evening (http://www.photoshopforphotographers.com/pscs2/download/movie-06.pdf)
        # Decompose, stretch levels, and recompose separately for A and B channels. Doing it this way allows the A/B mix
        # to be adjusted. Note that this is an approximation of the original method, as levels_stretch now operates in
        # linear space.
        drawA = self.AddLayerFromVisible(image, "LAB_A")
        drawB = self.AddLayerFromVisible(image, "LAB_B")
      
        # Decompose image to LAB
        for (draw, layer) in [(drawA, 1), (drawB, 2)]:
          result = self.Decompose(image, draw)
          imgLAB = result.index(1)  
          layersLAB = imgLAB.get_layers()

          # Select the appropriate layer, stretch the levels, and (workaround) adjust the gamma
          currentLayer = layersLAB[layer]
          currentLayer.levels_stretch()
          currentLayer.levels(Gimp.HistogramChannel.VALUE, 0, 1.0, True, 0.6, 0, 1.0, True)

          self.Recompose(imgLAB, currentLayer)
          imgLAB.delete()

          self.SetOpacityModeCombo(draw, 40, Gimp.LayerMode.HSL_COLOR)
          self.GaussianBlur(draw)

      case "Light Blue":
        self.sRGBCurvesSpline(baseLayer, Gimp.HistogramChannel.RED, [0, 0, 154/255, 141/255, 232/255, 1.0])
        self.sRGBCurvesSpline(baseLayer, Gimp.HistogramChannel.GREEN, [0, 0, 65/255, 48/255, 202/255, 215/255, 1.0, 1.0])
        self.sRGBCurvesSpline(baseLayer, Gimp.HistogramChannel.GREEN, [0, 21/255, 1.0, 1.0])
        self.sRGBCurvesSpline(baseLayer, Gimp.HistogramChannel.BLUE, [0, 0, 68/255, 89/255, 162/255, 206/255, 234/255, 1.0])
        baseLayer.levels(Gimp.HistogramChannel.VALUE, 25/255, 1.0, True, 2.2, 0, 1.0, True)

      case "Tokina Lens":
        self.sRGBCurvesSpline(baseLayer, Gimp.HistogramChannel.VALUE, [0, 20/255, 128/255, 153/255, 1.0, 1.0])
        self.sRGBCurvesSpline(baseLayer, Gimp.HistogramChannel.RED, [0, 0, 178/255, 165/255, 1.0, 1.0])
        self.sRGBCurvesSpline(baseLayer, Gimp.HistogramChannel.GREEN, [0, 5/255, 160/255, 166/255, 1.0, 1.0])

      case "Redscale":
      # The order of layer operations is important in this scheme
        blueLayer = self.AddLayerFromVisible(image, "Blue Filter")

        filter = Gimp.DrawableFilter.new(baseLayer, "gegl:channel-mixer", "Channel Mixer")
        config = filter.get_config()
        config.set_property('preserve-luminosity', True)
        config.set_property('rr-gain', 1.0)
        config.set_property('rg-gain', 0.0)
        config.set_property('rb-gain', 0.0)
        config.set_property('gr-gain', 0.0)
        config.set_property('gg-gain', 0.0)
        config.set_property('gb-gain', 0.0)
        config.set_property('br-gain', 0.0)
        config.set_property('bg-gain', 0.0)
        config.set_property('bb-gain', 0.0)
        filter.update()
        baseLayer.append_filter(filter)

        self.SetOpacityModeCombo(blueLayer, 40, Gimp.LayerMode.SCREEN)
        self.AddMask(blueLayer, Gimp.AddMaskType.COPY)
        self.FillWithColor(blueLayer, 0, 0, 1.0)
             
        self.sRGBCurvesSpline(baseLayer, Gimp.HistogramChannel.RED, [0, 0, 127/255, 190/255, 1.0, 1.0])
        self.sRGBCurvesSpline(baseLayer, Gimp.HistogramChannel.GREEN, [0, 0, 127/255, 62/255, 240/255, 1.0])
        self.sRGBCurvesSpline(baseLayer, Gimp.HistogramChannel.BLUE, [0, 0, 1.0, 0])

      case "Retro B/W":
        baseLayer.desaturate(Gimp.DesaturateMode.LUMINANCE)
        self.sRGBCurvesSpline(baseLayer, Gimp.HistogramChannel.RED, [0, 15/255, 1.0, 1.0])
        self.sRGBCurvesSpline(baseLayer, Gimp.HistogramChannel.BLUE, [0, 0, 1.0, 230/255])
        self.sRGBCurvesSpline(baseLayer, Gimp.HistogramChannel.VALUE, [0, 0, 63/255, 52/255, 191/255, 202/255, 1.0, 1.0])

      case "Paynes B/W":
        baseLayer.desaturate(Gimp.DesaturateMode.LUMINANCE) 
        baseLayer.colorize_hsl(215, 11, 0)

      case "Sepia":
        baseLayer.desaturate(Gimp.DesaturateMode.LUMINANCE) 
        baseLayer.colorize_hsl(30, 25, 0)

    # LAB channel inversion - do the inversion manually in non-linear space for best results
    if inversion in ("InvertA", "InvertB"):

        # Map inversion choice to LAB layer index
        layer_index = 1 if inversion == "InvertA" else 2

        # Decompose, apply inversion and recompose
        result = self.Decompose(image, baseLayer)
        imgLAB = result.index(1)
        layersLAB = imgLAB.get_layers()

        currentLayer = layersLAB[layer_index]
        currentLayer.invert(False)

        self.Recompose(imgLAB, currentLayer)
        imgLAB.delete()

    #
    # --- Post colorization and distortion effects ---
    # 

    if grain == True:
      self.Grain(baseLayer)
    
    if vignetteSize > 0:
      self.SetDefaultContexts()
      vignetteLayer = self.AddLayer(image, "Vignette", w, h)
      image.set_selected_layers([vignetteLayer, None])
      Gimp.Selection.none(image)

      self.DarkVignette(vignetteLayer, vignetteSize)
      self.SetOpacityModeCombo(vignetteLayer, 100, Gimp.LayerMode.OVERLAY)

      self.NoiseSpread(vignetteLayer)

    if dblVignette == True:
      self.SetDefaultContexts()
      dblVignetteLayer = self.AddLayer(image, "Double Vignette", w, h)
      image.set_selected_layers([dblVignetteLayer, None])
      Gimp.Selection.none(image)

      self.DarkVignette(dblVignetteLayer, vignetteSize)
      self.SetOpacityModeCombo(dblVignetteLayer, 50, Gimp.LayerMode.OVERLAY)

      self.NoiseSpread(dblVignetteLayer)

    if blackVignette == True:
      self.SetDefaultContexts()
      blkVignetteLayer = self.AddLayer(image, "Black Vignette", w, h)
      image.set_selected_layers([blkVignetteLayer, None])
      Gimp.Selection.none(image)

      self.DarkVignette(blkVignetteLayer, blkVignette)
      self.SetOpacityModeCombo(blkVignetteLayer, 50, Gimp.LayerMode.NORMAL)

    if overExposure == True:
      self.SetDefaultContexts()
      oeLayer = self.AddLayer(image, "Overexposure", w, h, 50, Gimp.LayerMode.OVERLAY)

      Gimp.context_swap_colors()
      Gimp.context_set_gradient_reverse(False)

      oeLayer.edit_gradient_fill(Gimp.GradientType.RADIAL, offset, False, 1, 0, True, centerX, centerY, 0, 0)
      self.NoiseSpread(oeLayer)

    # Restore context and close the undo group
    Gimp.displays_flush()
    Gimp.context_pop()
    image.undo_group_end()

    # Clean up Gegl
    Gegl.exit()

    return procedure.new_return_values(Gimp.PDBStatusType.SUCCESS, None)

  #
  # --- Methods for Gegl effects and PDB plugins ---
  #
  #applies the Softglow effect to a new layer
  def apply_softglow(self, image, layer, w, centerX, centerY):
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
    
    mask.edit_gradient_fill(Gimp.GradientType.RADIAL, glowOffset, False, 0, 0, False, centerX, centerY, 0, 0)

    # Create layers to subtract and add softglow effects
    subtractLayer = layer.copy()
    image.insert_layer(subtractLayer, None, -1)
    subtractLayer.set_name("SoftglowSubtract")
    subtractLayer.set_mode(Gimp.LayerMode.SUBTRACT)

    addLayer = Gimp.Layer.new_from_visible(image, image, "SoftglowAdd")
    image.insert_layer(addLayer, None, -1)
    addLayer.set_mode(Gimp.LayerMode.ADDITION)

    # Modify layer visibilities
    glowLayer.set_visible(False)
    subtractLayer.set_visible(False)

  def Decompose(self, image, draw):
    procedure = Gimp.get_pdb().lookup_procedure('plug-in-decompose')
    config = procedure.create_config()
    config.set_property('run-mode', Gimp.RunMode.NONINTERACTIVE)
    config.set_property('image', image)
    config.set_core_object_array('drawables', [draw])
    config.set_property('decompose-type', 'lab')
    config.set_property('layers-mode', True)
    config.set_property('use-registration', False)
    result = procedure.run(config)
    return result

  def EdgeBlur(self, layer, edgeBlur):
    # In place of (plug-in-mblur 1 img draw 2 motion_blur 0 blend_x blend_y)
    filter = Gimp.DrawableFilter.new(layer, "gegl:focus-blur", "Focus Blur")
    config = filter.get_config()
    config.set_property('blur-type', 'lens') #Enum: LENS_BLUR
    config.set_property('blur-radius', edgeBlur)
    config.set_property('highlight-factor', 0.35)
    config.set_property('highlight-threshold-low', 0.310)
    config.set_property('highlight-threshold-high', 1.0)
    # All other properties are defaulted
    filter.update()
    layer.append_filter(filter)
    return

  def GaussianBlur(self, draw, radius = 2.5):
    # Gaussian blur is used in place of the prefered gegl:lens-blur which cannot be applied
    # non-destructively as of Gimp 3.0.8
    filter = Gimp.DrawableFilter.new(draw, "gegl:gaussian-blur", "Gaussian Blur")
    config = filter.get_config()
    config.set_property('std-dev-x', radius)
    config.set_property('std-dev-y', radius)
    config.set_property('filter', 'auto') #Enum: AUTO
    config.set_property('abyss-policy', 1) #Enum: BLACK
    config.set_property('clip-extent', True) 
    filter.update()
    draw.append_filter(filter)
    return

  def Grain(self, layer):
    # This implementation is applied directly to the image and is a departure from the original Lomo script.
    # (plug-in-hsv-noise 1 img grain-layer 2 0 0 100)
    filter = Gimp.DrawableFilter.new(layer, "gegl:noise-hsv", "Grain")
    config = filter.get_config()
    config.set_property('holdness', 4.0)
    config.set_property('hue-distance', 0.0)
    config.set_property('saturation-distance', 0.0)
    config.set_property('value-distance', 0.30)
    filter.update()
    layer.append_filter(filter)
    return
  
  def LensDistortion(self, layer, wideAngle):
    # Adapted from (plug-in-lens-distortion 1 img draw 0 0 wide_angle 0 9 0)
    # and modified to give a better wide angle effect.
    filter = Gimp.DrawableFilter.new(layer, "gegl:lens-distortion", "Lens Distortion")
    config = filter.get_config()
    config.set_property('main', wideAngle)
    config.set_property('edge', wideAngle * 0.25)
    config.set_property('zoom', wideAngle * 0.80)
    config.set_property('brighten', 0)
    filter.update()
    layer.append_filter(filter)
    return
  
  def NoiseSpread(self, layer):
    # Adapted from (plug-in-spread 1 img vignette 50 50)
    filter = Gimp.DrawableFilter.new(layer, "gegl:noise-spread", "Noise Spread")
    config = filter.get_config()
    config.set_property('amount-x', 50.0)
    config.set_property('amount-y', 50.0)
    filter.update()
    layer.append_filter(filter)
    return
  
  def Recompose(self, image, draw):
    procedure = Gimp.get_pdb().lookup_procedure('plug-in-recompose')
    config = procedure.create_config()
    config.set_property('run-mode', Gimp.RunMode.NONINTERACTIVE)
    config.set_property('image', image)
    config.set_core_object_array('drawables', [draw])
    result = procedure.run(config)
    return result
  
  def SetContrast(self, layer, contrast):
    filter = Gimp.DrawableFilter.new(layer, "gegl:brightness-contrast", "Brightness and Contrast")
    config = filter.get_config()
    config.set_property('contrast', contrast)
    config.set_property('brightness', 0.0)
    filter.update()
    layer.append_filter(filter)
    return

  def SetSaturation(self, layer, saturation):
    filter = Gimp.DrawableFilter.new(layer, "gegl:saturation", "Saturation")
    config = filter.get_config()
    config.set_property('scale', saturation)
    config.set_property('colorspace', 0) # interpolation color space NATIVE
    filter.update()
    layer.append_filter(filter)
    return 

  def UnsharpMask(self, layer):
    # For this effect, the original code has been replaced with Unsharp Mask and
    # the sharpening effect has been moved lower in the stack.
    # It is applied with default values which can be edited after the plugin is run
    filter = Gimp.DrawableFilter.new(layer, "gegl:unsharp-mask", "Unsharp Mask")
    config = filter.get_config()
    config.set_property('std-dev', 2.0)
    config.set_property('scale', 0.0)
    config.set_property('threshold', 0.0)
    filter.update()
    layer.append_filter(filter)
    return

  def DarkVignette(self, layer, radius):
    # The original code has been replaced with the Vighette Gegl operation which allows for
    # non-destructive editing
    filter = Gimp.DrawableFilter.new(layer, "gegl:vignette", "Dark Vignette")
    config = filter.get_config()
    config.set_property('radius', radius)
    filter.update()
    layer.append_filter(filter)
    return

  #
  # --- Utilities ---
  #
	
  #adds a new layer with transparent fill
  def AddLayer(self, image, name, w, h, opacity = 100, mode = Gimp.LayerMode.NORMAL):
    layer = Gimp.Layer.new(image, name, w, h, Gimp.ImageType.RGBA_IMAGE, opacity, mode)
    image.insert_layer(layer, None, -1)
    layer.fill(Gimp.FillType.TRANSPARENT)

    return layer
  
  #adds a new layer from the visible image
  def AddLayerFromVisible(self, image, name):
    layer = Gimp.Layer.new_from_visible(image, image, name)
    image.insert_layer(layer, None, -1)

    return layer

	#adds a layer mask - fill(0) is white, fill(1) is black
  def AddMask(self, layer, fill):
    mask = layer.create_mask(fill)
    layer.add_mask(mask)

    return mask
  
	#adds a fill in specified mode and color (defaults to BLACK)
  def FillWithColor(self, layer, r = 0.0, g = 0.0, b = 0.0):
    fgColor = Gegl.Color.new('black')
    fgColor.set_rgba(r, g, b, 0.0)
    Gimp.context_set_foreground(fgColor)
    layer.edit_fill(Gimp.FillType.FOREGROUND)
    return

  #resets some contexts back to default values
  def SetDefaultContexts(self):

    Gimp.context_set_opacity(100)
    Gimp.context_set_paint_mode(Gimp.LayerMode.NORMAL)
    Gimp.context_set_gradient_blend_color_space(Gimp.GradientBlendColorSpace.RGB_PERCEPTUAL)
    Gimp.context_set_gradient_reverse(True)
    Gimp.context_set_gradient_fg_transparent()

    fgColor = Gegl.Color.new('black')
    bgColor = Gegl.Color.new('white')
    
    Gimp.context_set_foreground(fgColor)
    Gimp.context_set_background(bgColor)
    
    return

  #sets the opacity and mode of the given layer
  def SetOpacityModeCombo(self, layer, opacity, mode):
    layer.set_opacity(opacity)
    layer.set_mode(mode)
    return

  #
  # --- Methods for applying curves_spline in non-linear space ---
  #

  def sRGBCurvesSpline(self, drawable, channel, spline):
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
Gimp.main(Lomo.__gtype__, sys.argv)

