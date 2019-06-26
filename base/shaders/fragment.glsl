struct Material
{
  vec4 diffuse,ambient,emissive,specular;
  vec4 parameters;
};

struct Light
{
  vec4 direction;
  vec4 diffuse,ambient,specular;  
};

uniform int nlights;
uniform Light lights[Nlights];

uniform MaterialBuffer {
  Material Materials[Nmaterials];
};

uniform mat4 normMat;

flat in vec3 p[10];
in vec3 Normal;

in vec3 Parameter;

vec3 normal;

#ifdef EXPLICIT_COLOR
in vec4 Color; 
#endif

flat in int MaterialIndex;
out vec4 outColor;

// TODO: Integrate these constants into asy side
// PBR material parameters
vec3 PBRBaseColor; // Diffuse for nonmetals, reflectance for metals.
vec3 PBRSpecular; // Specular tint for nonmetals
float PBRMetallic; // Metallic/Nonmetals switch flag
float PBRF0; // Fresnel at zero for nonmetals
float PBRRoughness; // Roughness.
float PBRRoughnessSq; // used value of roughness, for a little bit more "smoothing"

// Here is a good paper on BRDF models...
// https://cdn2.unrealengine.com/Resources/files/2013SiggraphPresentationsNotes-26915738.pdf

uniform sampler2D environmentMap;
const float PI = acos(-1.0);
#ifdef ENABLE_TEXTURE
const float twopi=2*PI;
const float halfpi=PI/2;

// TODO: Enable different samples:
const int numSamples = 7;

// (x,y,z) -> (r, theta, phi);
// theta -> [0,\pi], "height" angle
// phi -> [0, 2\pi], rotation agnle
vec3 cart2spher(vec3 cart) {
  float x = cart.z;
  float y = cart.x;
  float z = cart.y;

  float r = length(cart);
  float phi = atan(y,x);
  float theta = acos(z/r);

  return vec3(r,phi,theta);
}

vec2 normalizedAngle(vec3 cartVec) {
  vec3 sphericalVec = cart2spher(cartVec);
  sphericalVec.y = sphericalVec.y / (2 * PI) - 0.25;
  sphericalVec.z = sphericalVec.z / PI;
  // sphericalVec.z = - sphericalVec.z;
  return sphericalVec.yz;
}
#endif

// h is the halfway vector between normal and light direction
// GGX Trowbridge-Reitz Approximation
float NDF_TRG(vec3 h, float roughness) {
  float ndoth = abs(dot(normal, h));
  float alpha2 = PBRRoughnessSq * PBRRoughnessSq;

  float denom = pow(ndoth * ndoth * (alpha2-1) + 1, 2);
  return alpha2/denom;
}
// Beckmann NDF Approximation
float NDF_B(vec3 h, float roughness) {
  float ndoth=abs(dot(normal,h));
  float alpha2 = PBRRoughnessSq * PBRRoughnessSq;

  float expnumer=pow(ndoth,2)-1;
  float expdenom=alpha2*pow(ndoth,2);

  float exppart=exp(expnumer/expdenom);

  float denom=alpha2*pow(ndoth,4);
  return exppart/denom;
}

float GGX_Geom(vec3 v) {
  float ndotv = abs(dot(v,normal));
  float ap = pow((1+PBRRoughness),2);
  float k = ap/8;

  return ndotv/((ndotv * (1-k)) + k);
}

float Geom(vec3 v, vec3 l) {
  return GGX_Geom(v) * GGX_Geom(l);
}

// Schlick's approximation
float Fresnel(vec3 h, vec3 v, float F0) {
  float hdotv = max(dot(h,v), 0.0);
  
  return F0 + (1-F0)*pow((1-hdotv),5);
}


vec3 BRDF(vec3 viewDirection, vec3 lightDirection) {
  // Lambertian diffuse 
  vec3 lambertian = PBRBaseColor;
  // Cook-Torrance model
  vec3 h = normalize(lightDirection + viewDirection);

  float omegain = abs(dot(viewDirection, normal));
  float omegaln = abs(dot(lightDirection, normal));

  float D = NDF_TRG(h, PBRRoughness);
  float G = Geom(viewDirection, lightDirection);
  float F = Fresnel(h, viewDirection, PBRF0);

  float rawReflectance = (D*G)/(4 * omegain * omegaln);

  vec3 dielectric = mix(lambertian, rawReflectance * PBRSpecular, F);
  vec3 metal = rawReflectance * PBRBaseColor;
  
  return mix(dielectric, metal, PBRMetallic);
}

vec3 point(float u, float v, float w) {
  return w*w*(w*p[0]+3*(u*p[1]+v*p[2]))+u*u*(3*(w*p[3]+v*p[7])+u*p[6])+
            6*u*v*w*p[4]+v*v*(3*(w*p[5]+u*p[8])+v*p[9]);
}

vec3 bu(float u, float v, float w) {
    // Compute one-third of the directional derivative of Bezier triangle p
    // in the u direction at point (u,v,w).
  return -w*w*p[0]+w*(w-2*u)*p[1]-2*w*v*p[2]+u*(2*w-u)*p[3]+2*v*(w-u)*p[4]
    -v*v*p[5]+u*u*p[6]+2*u*v*p[7]+v*v*p[8];
}

vec3 bv(float u, float v, float w) {
    // Compute one-third of the directional derivative of Bezier triangle p
    // in the v direction at point (u,v,w).
  return -w*w*p[0]-2*u*w*p[1]+w*(w-2*v)*p[2]-u*u*p[3]+2*u*(w-v)*p[4]
    +v*(2*w-v)*p[5]+u*u*p[7]+2*u*v*p[8]+v*v*p[9];
}

vec3 ComputeNormal(vec3 t) {
  return normalize(cross(bu(t.x,t.y,t.z),bv(t.x,t.y,t.z)));
}

void main()
{
  normal=normalize((normMat*vec4(Normal,0)).xyz);
//  normal=normalize((normMat*vec4(ComputeNormal(Parameter),0)).xyz);

vec4 Diffuse;
vec4 Ambient;
vec4 Emissive;
vec4 Specular;
vec4 parameters;
#ifdef EXPLICIT_COLOR
  if(MaterialIndex < 0) {
    int index=-MaterialIndex-1;
    Material m=Materials[index];
    Diffuse=Color;
    Ambient=Color;
    Emissive=Color;
    Specular=m.specular;
    parameters=m.parameters;
  } else {
    Material m=Materials[MaterialIndex];
    Diffuse=m.diffuse;
    Ambient=m.ambient;
    Emissive=m.emissive;
    Specular=m.specular;
    parameters=m.parameters;
  }
#else
  Material m=Materials[MaterialIndex];
  Diffuse=m.diffuse;
  Ambient=m.ambient;
  Emissive=m.emissive;
  Specular=m.specular;
  parameters=m.parameters;
#endif
  PBRRoughness=1-parameters[0];
  PBRMetallic=parameters[1];
  PBRF0=parameters[2];

  PBRBaseColor = Diffuse.rgb;
  PBRRoughnessSq = PBRRoughness * PBRRoughness;
  PBRSpecular = Specular.rgb;

    // Formally, the formula given a point x and direction \omega,
    // L_i = \int_{\Omega} f(x, \omega_i, \omega) L(x,\omega_i) (\hat{n}\cdot \omega_i) d \omega_i
    // where \Omega is the hemisphere covering a point, f is the BRDF function
    // L is the radiance from a given angle and position.

  vec3 color = Emissive.rgb;
  vec3 Z=vec3(0,0,1);
  vec3 pointLightRadiance=vec3(0,0,0);

  // as a finite point light, we have some simplification to the rendering equation.
  for(int i=0; i < nlights; ++i) {

    vec3 L = normalize(lights[i].direction.xyz);
    // what if we use the acutal view from (0,0,0) instead?
    // vec3 viewDirection = Z;
    float cosTheta = abs(dot(normal, L)); // $\omega_i \cdot n$ term
    float attn = 1; // if we have a good light direction.
    vec3 radiance = cosTheta * attn * lights[i].diffuse.rgb;

    // in our case, the viewing angle is always (0,0,1)... 
    // though the viewing angle does not matter in the Lambertian diffuse... 

    // totalRadiance += vec3(0,1,0)*Shininess;
    pointLightRadiance += BRDF(Z, L) * radiance;
  }
  color += pointLightRadiance.rgb;


#ifdef ENABLE_TEXTURE
#ifndef EXPLICIT_COLOR
    // environment radiance -- riemann sums, for now.
    // can also do importance sampling
    vec3 envRadiance=vec3(0,0,0);

    vec3 normalPerp = vec3(-normal.y, normal.x, 0);
    if (length(normalPerp) == 0) { // x, y = 0.

      normalPerp = vec3(1, 0, 0);
    }
    // we now have a normal basis for normal;
    // normal;
    normalPerp = normalize(normalPerp);
    vec3 normalPerp2 = normalize(cross(normal, normalPerp));

    const float step=1.0/numSamples;
    const float phistep=twopi*step;
    const float thetastep=halfpi*step;
    for (int iphi=0; iphi < numSamples; ++iphi) {
      float phi=iphi*phistep;
      for (int itheta=0; itheta < numSamples; ++itheta) {
        float theta=itheta*thetastep;

        vec3 azimuth=cos(phi)*normalPerp+sin(phi)*normalPerp2;
        vec3 L=sin(theta)*azimuth+cos(theta)*normal;

        vec3 rawRadiance=texture(environmentMap,normalizedAngle(L)).rgb;
        vec3 surfRefl=BRDF(Z,L);
        envRadiance += surfRefl*rawRadiance*sin(2.0*theta);
      }
    }
    envRadiance *= halfpi*step*step;
  
    // vec3 lightVector = normalize(reflect(-Z, normal));
    // vec2 anglemap = normalizedAngle(lightVector);
    // vec3 color = texture(environmentMap, anglemap).rgb;
    color += envRadiance.rgb;
#endif
#endif

//  vec3 visNormal = vec3(pow(0.5+0.5*Normal.y,1));
//  outColor=vec4(visNormal,Diffuse[3]);
//  outColor=vec4(normal,Diffuse[3]);
  outColor=vec4(color,Diffuse[3]);
}

