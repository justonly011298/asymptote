import math;

triple X=(1,0,0), Y=(0,1,0), Z=(0,0,1);

real[] operator ecast(triple v) {
  return new real[] {v.x, v.y, v.z, 1};
}

triple operator ecast(real[] a) {
  if(a.length != 4) abort("vector length of "+(string) a.length+" != 4");
  if(a[3] == 0) abort("camera is too close to object");
  return (a[0],a[1],a[2])/a[3];
}

typedef real[][] transform3;

triple operator * (transform3 t, triple v) {
  return (triple)(t*(real[]) v);
}

// A translation in 3d-space.
transform3 shift(triple v) {
  transform3 t=identity(4);
  t[0][3]=v.x;
  t[1][3]=v.y;
  t[2][3]=v.z;
  return t;
}

// A transformation representing rotation by an angle about an axis
// (in the right-handed direction).
// See http://www.cprogramming.com/tutorial/3d/rotation.html
transform3 rotate(real angle, triple axis) {
  real x=axis.x, y=axis.y, z=axis.z;
  real s=sin(angle), c=cos(angle), t=1-c;

  return new real[][] {
    {t*x^2+c,   t*x*y-s*z, t*x*z+s*y, 0},
    {t*x*y+s*z, t*y^2+c,   t*y*z-s*x, 0},
    {t*x*z-s*y, t*y*z+s*x, t*z^2+c,   0},
    {0,         0,         0,         1}};
}

// Transformation corresponding to moving the camera from the origin (looking
// down the negative z axis) to sitting at the point "from" (looking at the
// origin). Since, in actuality, we are transforming the points instead of
// the camera, we calculate the inverse matrix.
transform3 lookAtOrigin(triple from) {
  transform3 t=(from.x == 0 && from.y == 0) ? shift(-from) : 
    shift((0,0,-length(from)))*
    rotate(-pi/2,Z)*
    rotate(-colatitude(from),Y)*
    rotate(-azimuth(from),Z);
  return from.z >= 0 ? t : rotate(pi,Y)*t;
}

transform3 lookAt(triple from, triple to) {
  return lookAtOrigin(from-to)*shift(-to);
}

// Uses the homogenous coordinate to perform perspective distortion.  When
// combined with a projection to the XY plane, this effectively maps
// points in three space to a plane at a distance d from the camera.
transform3 perspective(triple camera) {
  transform3 t=identity(4);
  real d=length(camera);
  t[3][2]=-1/d;
  t[3][3]=0;
  return t*lookAtOrigin(camera);
}

transform3 orthographic(triple camera) {
  return lookAtOrigin(camera);
}

transform3 oblique(real angle=30) {
  transform3 t=identity(4);
  real x=Cos(angle)^2;
  t[0][2]=-x;
  t[1][2]=x-1;
  t[2][2]=0;
  return t;
}

transform3 oblique=oblique();

typedef pair projection(triple a);

pair projectXY(triple v) {
  return (v.x,v.y);
}

projection operator cast(transform3 t) {
  return new pair(triple v) {
    return projectXY(t*v);
  };
}

struct control {
  public triple post,pre;
  public bool active=false;
  void init(triple post, triple pre) {
    this.post=post;
    this.pre=pre;
    active=true;
  }
}

control operator init() {return new control;}
control nocontrol;
  
struct dir {
  public triple dir;
  public bool active=false;
  void init(triple v) {
    this.dir=v;
    active=true;
  }
}

dir operator init() {return new dir;}
dir nodir;

struct path3 {
  public triple[] nodes;
  public control[] control; // control points for segment starting at node
  public dir[] in,out;    // in and out directions for segment starting at node
  public bool[] straight; // true (--) or false (..)
  public bool cycles=false;

  void add(triple v) {
    nodes.push(v);
    control.push(nocontrol);
    in.push(nodir);
    out.push(nodir);
    straight.push(false);
 }

  void control(triple post, triple pre) {
    control c;
    c.init(post,pre);
    control[-1]=c;
  }

  void in(triple v) {
    dir d;
    d.init(v);
    in[-1]=d;
  }

  void out(triple v) {
    dir d;
    d.init(v);
    out[-1]=d;
  }

  void straight(bool b) {
    if(straight.length > 0) straight[-1]=b;
  }
}

int size(path3 g) {return g.nodes.length;}
triple point(path3 g, int k) {return g.nodes[k];}
bool cyclic(path3 g) {return g.cycles;}
int length(path3 g) {return g.cycles ? g.nodes.length : g.nodes.length-1;}
  
path3 operator init() {return new path3;}
  
// A guide3 is most easily represented as something that modifies a path3.
typedef void guide3(path3);

void nullpath3(path3) {};

guide3 operator init() {return nullpath3;}

guide3 operator cast(triple v) {
  return new void(path3 f) {
    f.add(v);
  };
}

guide3[] operator cast(triple[] v) {
  guide3[] g=new guide3[v.length];
  for(int i=0; i < v.length; ++i)
    g[i]=v[i];
  return g;
}

void cycle3 (path3 f) {
  f.straight.push(false);
  f.cycles=true;
}

guide3 operator controls(triple post, triple pre) {
  return new void(path3 f) {
    f.control(post,pre);
  };
};
  
guide3 operator controls(triple v)
{
  return operator controls(v,v);
}

guide3 operator -- (... guide3[] g) {
  return new void(path3 f) {
    // Apply the subguides in order.
    for(int i=0; i < g.length; ++i) {
      g[i](f);
      f.straight(true);
    }
  };
}

guide3 operator .. (... guide3[] g) {
  return new void(path3 f) {
    for(int i=0; i < g.length; ++i) {
      g[i](f);
    }
  };
}

guide3 operator spec(triple v, int p) {
  return new void(path3 f) {
    if(p == 0) f.out(v);
    else if(p == 1) f.in(v);
  };
}
  
path3 operator cast(guide3 g) {
  path3 f;
  g(f);
  return f;
}

path3[] operator cast(guide3[] g) {
  path3[] p=new path3[g.length];
  for(int i=0; i < g.length; ++i) {
    path3 f;
    g[i](f);
    p[i]=f;
  }
  return p;
}

pair project(triple v, projection P)
{
  return P(v);
}

struct Controls {
  triple c0,c1;
  
  // John Hobby's velocity formula (used by both MetaPost and Asymptote)
  real velocity(real theta, real phi, real t=1) {
    static real bound=4;
    static real a=sqrt(2);
    static real b=1/16;
    static real c=1.5*(sqrt(5)-1);
    static real d=1.5*(3-sqrt(5));

    real st=sin(theta), ct=cos(theta), sp=sin(phi), cp=cos(phi);

    real r=(2+a*(st-b*sp)*(sp-b*st)*(ct-cp))/(t*(3+c*ct+d*cp));

    if(r < 0) abort("negative");
    return (r > bound) ? bound : r;
  }

  // TODO: Implement tension.
  
  void init(triple z0, triple z1, triple d0, triple d1) {
    triple v=z1-z0;
    triple u=unit(z1-z0);
    real L=length(v);
    real theta=acos(dot(unit(d0),u));
    real phi=acos(dot(unit(d1),u));
    if(dot(cross(d0,v),cross(v,d1)) < 0) phi=-phi;
    c0=z0+d0*L*velocity(theta,phi);
    c1=z1-d1*L*velocity(phi,theta);
  }
}

Controls operator init() {return new Controls;}
  
path project(path3 g, projection P)
{
  guide pg;
  typedef guide connector(... guide[]);
  
  // Propagate directions across nodes.
  for(int i=0; i < length(g); ++i) {
    int next=(i+1 == size(g)) ? 0 : i+1;
    if(!g.in[i].active && g.out[next].active) {
      g.in[i]=g.out[next];
      g.in[i].active=true;
    }
    if(!g.out[next].active && g.in[i].active) {
      g.out[next]=g.in[i];
      g.out[next].active=true;
    }
  }
  
  // Compute missing control points where possible.
  for(int i=0; i < length(g); ++i) {
    int next=(i+1 == size(g)) ? 0 : i+1;
    if(!g.control[i].active && g.out[i].active && g.in[i].active) {
      Controls C;
      C.init(point(g,i),point(g,next),g.out[i].dir,g.in[i].dir);
      control c;
      c.init(C.c0,C.c1);
      g.control[i]=c;
    }
  }
  
  // Construct the path.
  for(int i=0; i < size(g); ++i) {
    connector join=g.straight[i] ? operator -- : operator ..;
    if(g.control[i].active)
      pg=join(pg,P(point(g,i))..controls P(g.control[i].post) and 
	      P(g.control[i].pre)..nullpath);
    else if(g.out[i].active)
      pg=join(pg,P(point(g,i)){P(g.out[i].dir)}..nullpath);
    else if(g.in[i].active)
      pg=pg..{P(g.in[i].dir)}nullpath;
    else pg=join(pg,P(point(g,i)));
  }
  return cyclic(g) ? (g.straight[-1] ? pg--cycle : pg..cycle) : pg;
}

path[] project(path3[] g, projection P)
{
  path[] p=new path[g.length];
  for(int i=0; i < g.length; ++i) 
    p[i]=project(g[i],P);
  return p;
}
  
public projection currentprojection=perspective((5,4,2));

path operator cast(triple v) {
  return project(v,currentprojection);
}

path operator cast(guide3 g) {
  return project(g,currentprojection);
}

path[] operator cast(path3[] g) {
  return project(g,currentprojection);
}

guide3[] operator ^^ (guide3 p, guide3 q) 
{
  return new guide3[] {p,q};
}

guide3[] operator ^^ (guide3 p, guide3[] q) 
{
  return concat(new guide3[] {p},q);
}

guide3[] operator ^^ (guide3[] p, guide3 q) 
{
  return concat(p,new guide3[] {q});
}

guide3[] operator ^^ (guide3[] p, guide3[] q) 
{
  return concat(p,q);
}

// The graph of a function along a path.
guide3 graph(real f(pair z), path p, int n=10) {
  triple F(pair z) {
    return (z.x,z.y,f(z));
  }

  guide3 g;
  for(int i=0; i < n*length(p); ++i) {
    pair z=point(p,i/n);
    g=g--F(z);
  }
  return cyclic(p) ? g--cycle3 : g--F(endpoint(p));
}

picture surface(real f(pair z), pair min, pair max, int n=20, int subn=1, 
		pen surfacepen=lightgray, pen meshpen=currentpen,
		projection P=currentprojection)
{
  picture pic;

  void drawcell(pair a, pair b) {
    guide3 g=graph(f,box(a,b),subn);
    filldraw(pic,project(g,P),surfacepen,meshpen);
  }

  pair sample(int i, int j) {
    return (interp(min.x,max.x,i/n),
            interp(min.y,max.y,j/n));
  }

  for(int i=0; i < n; ++i)
    for(int j=0; j < n; ++j)
      drawcell(sample(i,j),sample(i+1,j+1));

  return pic;
}

guide3[] box3d(triple v1, triple v2)
{
  return
    (v1.x,v1.y,v1.z)--
    (v1.x,v1.y,v2.z)--
    (v1.x,v2.y,v2.z)--
    (v1.x,v2.y,v1.z)--
    (v1.x,v1.y,v1.z)--
    (v2.x,v1.y,v1.z)--
    (v2.x,v1.y,v2.z)--
    (v2.x,v2.y,v2.z)--
    (v2.x,v2.y,v1.z)--
    (v2.x,v1.y,v1.z)^^
    (v2.x,v2.y,v1.z)--
    (v1.x,v2.y,v1.z)^^
    (v1.x,v2.y,v2.z)--
    (v2.x,v2.y,v2.z)^^
    (v2.x,v1.y,v2.z)--
    (v1.x,v1.y,v2.z);
}
