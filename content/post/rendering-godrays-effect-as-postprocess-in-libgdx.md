+++

title = "Rendering a godrays effect as postprocess in LibGDX"
author = "BiziOS"
tags = ["programming", "libgdx", "glsl", "java", "shader", "opengl", "godrays", "lightshafts", "volumetric light scattering"]
draft = false
type = "post"
date = "2017-03-16T11:49:20+01:00"

+++


In this post we're going to implement a 2D "godrays" effect using shaders in LibGDX. This article is based on the [13th chapter](http://http.developer.nvidia.com/GPUGems3/gpugems3_ch13.html) of nvidia's GPU Gems series. Since we're using LibGDX we're going to use the OpenGL Shading Language (GLSL), but the basic concept remains the same for any other shading language.

### Introduction

This effect aims to reproduce how the light interacts with the atmosphere in the real world. Since we rarely see light in a vacuum, between an observer and a light source there will always be some kind of medium - most likely air - in which the light propagates. Under the right conditions, when enough light-occluding material (gas, water vapor, etc...) is present in the medium, light-occluding objects in front of the light source will cast volumes of shadows, creating beautiful shafts of light.

<img id="godraysimg" src="https://carlabrennan.files.wordpress.com/2012/08/god-rays-6.jpg" title="Godrays in FarCry 4" style="width:700px; margin: auto;">

### The basic idea

Actually, there is a fair bit of maths involved in modelling volumetric light scattering (this is the badass name of the godrays effect). We face two possibilities here:

1. I'll explain all the maths, with the risk of boring you and possibly (probably) myself while writing this. We don't want that, do we?

2. I'll explain only the high level idea of the technique and, if you're still interested in the maths, you can read the [nvidia's article](http://http.developer.nvidia.com/GPUGems3/gpugems3_ch13.html).

Honestly, it is not essential to know all the maths of the underlying model, since it all boils down to approximations for the fact that we're working in 2D screen space and we don't have full volumetric information to determine occlusion (this is fortunate for us since we're reproducing the effect in 2D, where there is no volumetric information whatsoever!).
The core of this technique is the fragment shader. As already mentioned, we need to approximate the probability of occlusion of each pixel, since we don't have any volumetric information at our disposal. To do that, we can sample the texture multiple times along the ray from the pixel to the light source, summing all the samples together. The proportion of samples that hit the emissive region versus those that strike occluders gives us the desired percentage of occlusion.
<img id="expl1" title="sampling along pixel-to-center ray" src="/res/post_godrays_expl1.png" style="width: 50%; margin: 10px auto">
In doing this, we generate a sort of radial blur from the center of the light source, that creates the illusion of shafts of light. We can then render this image on top of the scene using additive blending to obtain a glowing effect.

### Shader implementation
Here is the fragment shader code:
```glsl
varying vec4 v_color;
varying vec2 v_texCoords;

uniform sampler2D u_texture;
//The center (in screen coordinates) of the light source
uniform vec2 cent;

//The width of the blur (the stronger the further each pixel is gonna sample)
const float blurWidth = -0.85;
//the number of samples
#define NUM_SAMPLES 100

void main() {
	//compute ray from pixel to light center
	vec2 tc = v_texCoords - cent;
	//output color
	vec3 color = vec3(0.0);

	//sample the texture NUM_SAMPLES times
	for(int i = 0; i < NUM_SAMPLES; i++) {
		//sample the texture on the pixel-to-center ray getting closer to the center every iteration
    	float scale = 1.0 + blurWidth * (float(i) / float(NUM_SAMPLES - 1));
        //summing all the samples togheter
    	color += (texture2D(u_texture, (tc * scale) + cent).xyz) / float(NUM_SAMPLES);
  	}
	//return final color
	gl_FragColor = vec4(color, 1.0);
}
```

Note that we need to divide each sample by the total number of samples in order to create an average color.

### Fixing problems

As mentioned before, this technique is only a 2D screen space approximation of light scattering, and it has some problems. We are approximating each pixel occlusion by averaging its value with the pixels on the pixel-to-center line and this may cause unwanted stripes due to texture variations. To resolve this issue we need to render occluders in full black, maintaining only the alpha channel, in order to render only a silhouette of the occluder. This can be done simply using this shader:
```glsl
varying LOWP vec4 v_color;
varying vec2 v_texCoords;

uniform sampler2D u_texture;
uniform vec4 color;

void main() {
	vec4 sample = texture2D(u_texture, v_texCoords);
	gl_FragColor = vec4(color.rgb, sample.a) * sample;
}
```
setting the `color` uniform to white (or whatever color you want) when rendering the sun and then to black when rendering occluders, enables us to render only their silhouettes. This removes the accidental stripes from the final result.
