# Swift Phone-ton Rendering

Authors: Jed Fox, Coco Kaleel\
Course: Brown University [CSCI 2240: Advanced Computer Graphics](https://cs2240.graphics), Spring 2023

## Overview

This is a path tracer written in Metal (so it runs on Mac GPUs), including support for realistic subsurface scattering. We implemented 4 BRDFs/BSSDFs: diffuse reflectance, ideal specular (mirror), Fresnel dielectric materials (e.g. glass) that take index of refraction into account, and an approximation of subsurface scattering.

Additionally, we have a GUI (graphical user interface) that allows users to modify parameters related to tone mapping, modify render settings, and pick from subsurface-scattering parameter presets.

Editors beware: we did implement the subsurface scattering approximation - it does not look that good. We took some liberties with the manipulation of 3-channel color (we didn't want to triple path-trace each pixel) and sampling strategies for the diffusion approximation.

## Building

Open the .xcodeproj file in Xcode. Build and run. The app will run on macOS as well as iOS/iPadOS. It runs on both Intel and M1 Macs, but we've noticed significantly faster runtimes in M1 Macs. Additionally, to run, the application will request access to your Documents folder.

## Usage

Select a model using the button at the top of the configuration section. You can either choose a built-in model or open a `.obj` file from your system.

You can toggle on/off the different BRDFs/BSSDFs using the checkboxes below the model picker.

## Sources

- “[A Practical Model for Subsurface Light Transport](https://graphics.stanford.edu/papers/bssrdf/bssrdf.pdf)” by Henrik Wann Jensen, Stephen R. Marschner, Marc Levoy, & Pat Hanrahan
- “[Accelerating ray tracing using Metal](https://developer.apple.com/documentation/metal/metal_sample_code_library/accelerating_ray_tracing_using_metal)” (Apple sample code)
- Xcode “Multiplatform Game” template
