#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sc68/sc68.h>
int main(int argc,char**argv){
  sc68_init_t init; memset(&init,0,sizeof init);
  if(sc68_init(&init)){printf("init fail\n");return 1;}
  sc68_create_t cr; memset(&cr,0,sizeof cr); cr.sampling_rate=44100;
  sc68_t* s=sc68_create(&cr);
  if(!s){printf("create fail\n");return 1;}
  if(sc68_load_uri(s,argv[1])){printf("LOAD FAIL: %s\n",sc68_error(s));return 1;}
  sc68_music_info_t in;
  if(!sc68_music_info(s,&in,0,0))
    printf("INFO tracks=%d album='%s' title='%s' replay='%s'\n",
      in.tracks, in.album?in.album:"", in.title?in.title:"", in.replay?in.replay:"");
  int track=(argc>2)?atoi(argv[2]):1;
  sc68_play(s,track,1);
  short buf[2048]; long peak=0,frames=0;
  for(int i=0;i<300;i++){ int n=1024; int c=sc68_process(s,buf,&n);
    for(int j=0;j<n*2;j++){int a=buf[j]<0?-buf[j]:buf[j]; if(a>peak)peak=a;} frames+=n;
    if(c&SC68_END)break; }
  printf("RENDER track=%d frames=%ld peak=%ld -> %s\n",track,frames,peak,peak>50?"SOUND":"silent");
  return 0;
}
