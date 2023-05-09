# Swift Phone-ton Rendering

Authors: Jed Fox, Coco Kaleel\
Course: [CSCI 2240: Advanced Computer Graphics](https://cs2240.graphics), Spring 2023

## Overview

This is a path tracer written in Metal, including support for realistic subsurface scattering.

## Building

Open the .xcodeproj file in Xcode. Build and run. The app will run on macOS as well as iOS/iPadOS.

## Usage

Select a model using the button at the top of the configuration section. You can either choose a built-in model or open a `.obj` file from your system.

You can toggle on/off the different BRDFs/BSSDFs using the checkboxes below the model picker.

## Sources

- “[A Practical Model for Subsurface Light Transport](https://graphics.stanford.edu/papers/bssrdf/bssrdf.pdf)” by Henrik Wann Jensen, Stephen R. Marschner, Marc Levoy, & Pat Hanrahan
- “[Accelerating ray tracing using Metal](https://developer.apple.com/documentation/metal/metal_sample_code_library/accelerating_ray_tracing_using_metal)” (Apple sample code)
- Xcode “Multiplatform Game” template
