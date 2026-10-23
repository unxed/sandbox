/* Private-display screenshot/window-tree diagnostic; no Wine needed.
 * cc -O2 -Wall -Wextra -Werror gui-suite-x11-snapshot.c -o gui-suite-x11-snapshot -lX11
 */
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <stdio.h>
#include <stdlib.h>

static unsigned char component(unsigned long pixel,unsigned long mask)
{
    unsigned int shift=0;if(!mask)return 0;
    while(!(mask&1)){mask>>=1;shift++;}
    return (unsigned char)(((pixel>>shift)&mask)*255/mask);
}
static void tree(Display *d,Window w,int depth)
{
    XWindowAttributes a;Window root,parent,*children=NULL,owner=0;unsigned int count=0,i;char *name=NULL;
    if(depth>12||!XGetWindowAttributes(d,w,&a))return;
    XFetchName(d,w,&name);XGetTransientForHint(d,w,&owner);
    printf("depth=%d xid=0x%lx transient=0x%lx mapped=%d rect=%d,%d,%d,%d name=%s\n",
           depth,w,owner,a.map_state,a.x,a.y,a.width,a.height,name?name:"");
    if(name)XFree(name);
    if(XQueryTree(d,w,&root,&parent,&children,&count)){
        for(i=0;i<count;i++)tree(d,children[i],depth+1);
        if(children)XFree(children);
    }
}
int main(int argc,char **argv)
{
    Display *d;Window root;XWindowAttributes a;XImage *image;FILE *out;int x,y;
    if(argc!=2){fprintf(stderr,"usage: gui-suite-x11-snapshot OUTPUT.ppm\n");return 2;}
    d=XOpenDisplay(NULL);if(!d){fprintf(stderr,"cannot open private test display\n");return 2;}
    root=DefaultRootWindow(d);XGetWindowAttributes(d,root,&a);tree(d,root,0);
    image=XGetImage(d,root,0,0,(unsigned int)a.width,(unsigned int)a.height,AllPlanes,ZPixmap);
    if(!image){XCloseDisplay(d);return 1;}
    out=fopen(argv[1],"wb");if(!out){XDestroyImage(image);XCloseDisplay(d);return 1;}
    fprintf(out,"P6\n%d %d\n255\n",a.width,a.height);
    for(y=0;y<a.height;y++)for(x=0;x<a.width;x++){
        unsigned long pixel=XGetPixel(image,x,y);unsigned char rgb[3];
        rgb[0]=component(pixel,image->red_mask);rgb[1]=component(pixel,image->green_mask);rgb[2]=component(pixel,image->blue_mask);
        fwrite(rgb,1,3,out);
    }
    fclose(out);XDestroyImage(image);XCloseDisplay(d);return 0;
}
