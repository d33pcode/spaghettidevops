+++

type = "post"
title = "Rendering a godrays effect as postprocess in LibGDX using shaders"
draft = false
author = "bamless"
description = "A tutorial for writing a volumetric light scattering shader in GLSL and LibGDX"
date = "2017-03-22T13:02:20+01:00"
tags = ["programming", "libgdx", "glsl", "java", "shader", "opengl", "godrays", "lightshafts", "volumetric light scattering"]

+++


In this post we're going to implement a 2D "godrays" effect using shaders in LibGDX. This article is based on the [13th chapter](http://http.developer.nvidia.com/GPUGems3/gpugems3_ch13.html) of nvidia's GPU Gems series. Since we're using LibGDX we're going to use the OpenGL Shading Language (GLSL), but the basic concept remains the same for any other shading language.

# Introduction

This effect aims to reproduce how the light interacts with the atmosphere in the real world. Since we rarely see light in a vacuum, between an observer and a light source there will always be some kind of medium - most likely air - in which the light propagates. Under the right conditions, when enough light-occluding material (gas, water vapor, etc...) is present in the medium, light-occluding objects in front of the light source will cast volumes of shadows, creating beautiful shafts of light.

![](https://carlabrennan.files.wordpress.com/2012/08/god-rays-6.jpg "Godrays in FarCry 4")

# The basic idea

Actually, there is a fair bit of maths involved in modeling volumetric light scattering (this is the badass name of the godrays effect). We face two possibilities here:

1. I'll explain all the maths, with the risk of boring you and possibly (probably) myself while writing this. We don't want that, do we?

2. I'll explain only the high level idea of the technique and, if you're still interested in the maths, you can read the [nvidia's article](http://http.developer.nvidia.com/GPUGems3/gpugems3_ch13.html).

Honestly, it is not essential to know all the maths of the underlying model, since it all boils down to approximations for the fact that we're working in 2D screen space and we don't have full volumetric information to determine occlusion (this is fortunate for us since we're reproducing the effect in 2D, where there is no volumetric information whatsoever!). The core of this technique is the fragment shader. As already mentioned, we need to approximate the probability of occlusion of each pixel, since we don't have any volumetric information at our disposal. To do that, we can sample the texture multiple times along the ray from the pixel to the light source. The proportion of samples that hit the emissive region versus those that strike occluders gives us the desired percentage of occlusion.

[![](/res/rendering-godrays/post_godrays_expl1.png "sampling along pixel-to-center ray")](/res/rendering-godrays/post_godrays_expl1.png)

In doing this, we generate a sort of radial blur from the center of the light source, that creates the shafts of light. We can then render this image on top of the scene using additive blending to obtain the godrays effect.

# Shader implementation

Here is the fragment shader code:

```c
varying vec4 v_color;
varying vec2 v_texCoords;

uniform sampler2D u_texture;
//The center (in screen coordinates) of the light source
uniform vec2 cent;

//The width of the blur (the smaller it is the further each pixel is going to sample)
const float blurWidth = -0.85;
//the number of samples
#define NUM_SAMPLES 100

void main() {
    //compute ray from pixel to light center
    vec2 ray = v_texCoords - cent;
    //output color
    vec3 color = vec3(0.0);

    //sample the texture NUM_SAMPLES times
    for(int i = 0; i < NUM_SAMPLES; i++) {
        //sample the texture on the pixel-to-center ray getting closer to the center every iteration
        float scale = 1.0 + blurWidth * (float(i) / float(NUM_SAMPLES - 1));
        //summing all the samples togheter
        color += (texture2D(u_texture, (ray * scale) + cent).xyz) / float(NUM_SAMPLES);
      }
    //return final color
    gl_FragColor = vec4(color, 1.0);
}
```

The code is pretty simple. In the first line of the main function we calculate the ray from the pixel to the center of the light source (that is passed as an uniform) simply by subtracting the center coordinates from the texture coordinates. Then we sample the texture N times, sampling along the ray and getting closer to the center at each iteration. The scale variable stores the distance at which we need to sample, computed using the index of the iteration and the blurWidth constant. finally, we use the scale variable together with the ray and center coords to sample the texture, and we add the sampled color to the color variable, which stores the average of all the samples. At the end of the N iterations the color variable will hold our occlusion percentage approximation.

# Fixing problems

As mentioned before, this technique is only a 2D screen space approximation of light scattering, and it has some problems. We are approximating each pixel's occlusion by averaging its value with the pixels on the pixel-to-center line and this may cause unwanted stripes due to texture variations. To resolve this issue we need to render occluders in full black, maintaining only the alpha channel, in order to render only a silhouette of the occluder. This can be done easily enough using this shader:

```c
varying LOWP vec4 v_color;
varying vec2 v_texCoords;

uniform sampler2D u_texture;
uniform vec4 color;

void main() {
    vec4 sample = texture2D(u_texture, v_texCoords);
    gl_FragColor = vec4(color.rgb, sample.a) * sample;
}
```

setting the `color` uniform to white (or whatever color you want) when rendering the sun and then to black when rendering occluders, enables us to draw only their silhouettes. This removes the accidental stripes from the final result and improves the occlusion-percentage approximation.

# Final result

The final result, along with all the rendering steps, is showed in the following images:

<style type="text/css">
.result {
	display: inline-block;
	margin-left: auto;
  margin-right: auto;
	margin-top: auto !important;
	margin-bottom auto !important;
  width: 250px;
}
#imgContainer {
    text-align:center;
}
</style>
<div id="imgContainer">
<img class="result" src="/res/rendering-godrays/a.jpg">
<img class="result" src="/res/rendering-godrays/b.jpg">
<img class="result" src="/res/rendering-godrays/c.jpg">
<img class="result" src="/res/rendering-godrays/d.jpg">
</div>

**From left to right:** scene without the effect, FBO with black occluders silhouettes, occluders FBO after occlusion-approximation pass, scene with occluders FBO rendered on top of it with additive blending.

At this point you might be wondering where the Java code is. The answer is that i'm not going to explain the code line by line, because i already wrote it and i don't want to do it again, and because it is pretty straight forward, and if you clicked on a LibGDX tutorial you will understand it without any problems. The focus of this article was to explain _how_ to write a shader that creates a godrays effect, the platform on which it is done is only a detail. \ Here's the link to the code (navigate to the lightshafts package) <https://github.com/bamless/libgdx-tests>.
