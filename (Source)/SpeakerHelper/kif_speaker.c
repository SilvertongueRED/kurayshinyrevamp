/*=============================================================================
 *  kif_speaker.exe  -  KIF Controller-Speaker audio router
 *  Plays a single sound file to a SPECIFIC audio output device (e.g. the
 *  DualSense built-in speaker, exposed by Windows as "Wireless Controller").
 *    kif_speaker.exe play "<device-substr>" "<file>" <volume0-100> <pitch%>
 *    kif_speaker.exe probe "<out-file>"
 *  miniaudio (c) David Reid - MIT-0; stb_vorbis (c) Sean Barrett - public domain
 *===========================================================================*/
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shellapi.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>

#include "stb_vorbis.c"

#define MINIAUDIO_IMPLEMENTATION
#define MA_NO_ENCODING
#define MA_NO_GENERATION
#include "miniaudio.h"

static void ascii_lower(char *s){ for(; *s; ++s) if(*s>='A'&&*s<='Z') *s+=32; }

static char *wide_to_utf8(const wchar_t *w){
    int n; char *out;
    if(!w) return NULL;
    n=WideCharToMultiByte(CP_UTF8,0,w,-1,NULL,0,NULL,NULL);
    if(n<=0) return NULL;
    out=(char*)malloc((size_t)n);
    if(!out) return NULL;
    WideCharToMultiByte(CP_UTF8,0,w,-1,out,n,NULL,NULL);
    return out;
}

static int contains_ci(const char *haystack, const char *needle){
    char hb[512], nb[256];
    if(!haystack||!needle||!*needle) return 0;
    strncpy(hb,haystack,sizeof(hb)-1); hb[sizeof(hb)-1]=0;
    strncpy(nb,needle,sizeof(nb)-1);   nb[sizeof(nb)-1]=0;
    ascii_lower(hb); ascii_lower(nb);
    return strstr(hb,nb)!=NULL ? 1 : 0;
}

static int looks_like_controller(const char *name){
    return contains_ci(name,"dualsense") ||
           contains_ci(name,"wireless controller") ||
           contains_ci(name,"dualshock");
}

static int looks_like_headphones(const char *name){
    return contains_ci(name,"headphone") || contains_ci(name,"headset") ||
           contains_ci(name,"earphone")  || contains_ci(name,"earbud")  ||
           contains_ci(name,"airpod");
}

static int read_file_w(const wchar_t *wpath, unsigned char **out, size_t *outlen){
    FILE *f=_wfopen(wpath,L"rb"); long sz; unsigned char *buf;
    *out=NULL; *outlen=0;
    if(!f) return 0;
    if(fseek(f,0,SEEK_END)!=0){ fclose(f); return 0; }
    sz=ftell(f);
    if(sz<=0){ fclose(f); return 0; }
    if(fseek(f,0,SEEK_SET)!=0){ fclose(f); return 0; }
    buf=(unsigned char*)malloc((size_t)sz);
    if(!buf){ fclose(f); return 0; }
    if(fread(buf,1,(size_t)sz,f)!=(size_t)sz){ free(buf); fclose(f); return 0; }
    fclose(f);
    *out=buf; *outlen=(size_t)sz;
    return 1;
}

typedef struct {
    ma_int16 *pcm;
    ma_uint64 frames;
    ma_uint32 channels;
    double    cursor;
    double    pitch;
    float     gain;
    volatile LONG finished;
} clip_t;

static void data_callback(ma_device *dev, void *out, const void *in, ma_uint32 frameCount){
    clip_t *c=(clip_t*)dev->pUserData;
    ma_int16 *dst=(ma_int16*)out;
    ma_uint32 i,ch;
    (void)in;
    if(!c||!c->pcm){ memset(out,0,(size_t)frameCount*dev->playback.channels*sizeof(ma_int16)); return; }
    for(i=0;i<frameCount;++i){
        ma_uint64 idx=(ma_uint64)c->cursor;
        if(idx>=c->frames){
            for(ch=0;ch<c->channels;++ch) *dst++=0;
            InterlockedExchange(&c->finished,1);
        } else {
            const ma_int16 *src=c->pcm+idx*c->channels;
            for(ch=0;ch<c->channels;++ch){
                int v=(int)(src[ch]*c->gain);
                if(v> 32767) v= 32767;
                if(v<-32768) v=-32768;
                *dst++=(ma_int16)v;
            }
            c->cursor+=c->pitch;
        }
    }
}

static int decode_to_s16(const wchar_t *wpath, ma_int16 **pcm,
                         ma_uint64 *frames, ma_uint32 *channels, ma_uint32 *rate){
    unsigned char *bytes=NULL; size_t len=0; int is_ogg; size_t wl;
    if(!read_file_w(wpath,&bytes,&len)) return 0;
    wl=wcslen(wpath);
    is_ogg=(wl>=4 && wpath[wl-4]==L'.' &&
            (wpath[wl-3]==L'o'||wpath[wl-3]==L'O') &&
            (wpath[wl-2]==L'g'||wpath[wl-2]==L'G') &&
            (wpath[wl-1]==L'g'||wpath[wl-1]==L'G'));
    if(is_ogg){
        int ch=0,sr=0; short *out=NULL;
        int n=stb_vorbis_decode_memory(bytes,(int)len,&ch,&sr,&out);
        free(bytes);
        if(n<0||!out||ch<=0||sr<=0){ if(out) free(out); return 0; }
        *pcm=(ma_int16*)out; *frames=(ma_uint64)n;
        *channels=(ma_uint32)ch; *rate=(ma_uint32)sr;
        return 1;
    } else {
        ma_decoder dec;
        ma_decoder_config cfg=ma_decoder_config_init(ma_format_s16,0,0);
        ma_uint64 total=0,readFrames=0; ma_int16 *buf;
        if(ma_decoder_init_memory(bytes,len,&cfg,&dec)!=MA_SUCCESS){ free(bytes); return 0; }
        if(ma_decoder_get_length_in_pcm_frames(&dec,&total)!=MA_SUCCESS||total==0){
            ma_decoder_uninit(&dec); free(bytes); return 0;
        }
        buf=(ma_int16*)malloc((size_t)total*dec.outputChannels*sizeof(ma_int16));
        if(!buf){ ma_decoder_uninit(&dec); free(bytes); return 0; }
        ma_decoder_read_pcm_frames(&dec,buf,total,&readFrames);
        *pcm=buf; *frames=readFrames;
        *channels=dec.outputChannels; *rate=dec.outputSampleRate;
        ma_decoder_uninit(&dec); free(bytes);
        return (readFrames>0)?1:0;
    }
}

static int do_play(const wchar_t *wDevSubstr, const wchar_t *wFile, int vol, int pitch){
    char *devSubstr=wide_to_utf8(wDevSubstr);
    ma_context ctx;
    ma_device_info *pPlayback=NULL,*pCapture=NULL;
    ma_uint32 playbackCount=0,captureCount=0,i;
    ma_device_id targetId; int haveTarget=0;
    ma_int16 *pcm=NULL; ma_uint64 frames=0; ma_uint32 channels=0,rate=0;
    clip_t clip; ma_device_config dcfg; ma_device device;
    DWORD startTick; double maxMs;

    if(vol<0) vol=0; if(vol>100) vol=100;
    if(pitch<25) pitch=25; if(pitch>400) pitch=400;

    if(ma_context_init(NULL,0,NULL,&ctx)!=MA_SUCCESS){ free(devSubstr); return 3; }
    if(ma_context_get_devices(&ctx,&pPlayback,&playbackCount,&pCapture,&captureCount)!=MA_SUCCESS){
        ma_context_uninit(&ctx); free(devSubstr); return 3;
    }
    for(i=0;i<playbackCount;++i){
        const char *nm=pPlayback[i].name;
        int hit=(devSubstr&&*devSubstr)?contains_ci(nm,devSubstr):looks_like_controller(nm);
        if(hit){ targetId=pPlayback[i].id; haveTarget=1; break; }
    }
    if(!haveTarget){
        for(i=0;i<playbackCount;++i){
            if(looks_like_controller(pPlayback[i].name)){ targetId=pPlayback[i].id; haveTarget=1; break; }
        }
    }
    free(devSubstr);
    if(!haveTarget){ ma_context_uninit(&ctx); return 2; }

    if(!decode_to_s16(wFile,&pcm,&frames,&channels,&rate)||frames==0||channels==0){
        if(pcm) free(pcm); ma_context_uninit(&ctx); return 4;
    }

    memset(&clip,0,sizeof(clip));
    clip.pcm=pcm; clip.frames=frames; clip.channels=channels;
    clip.cursor=0.0; clip.pitch=(double)pitch/100.0;
    clip.gain=(float)vol/100.0f; clip.finished=0;

    dcfg=ma_device_config_init(ma_device_type_playback);
    dcfg.playback.pDeviceID=&targetId;
    dcfg.playback.format=ma_format_s16;
    dcfg.playback.channels=channels;
    dcfg.sampleRate=rate;
    dcfg.dataCallback=data_callback;
    dcfg.pUserData=&clip;

    if(ma_device_init(&ctx,&dcfg,&device)!=MA_SUCCESS){ free(pcm); ma_context_uninit(&ctx); return 5; }
    if(ma_device_start(&device)!=MA_SUCCESS){ ma_device_uninit(&device); free(pcm); ma_context_uninit(&ctx); return 6; }

    startTick=GetTickCount();
    maxMs=((double)frames/(double)rate)*1000.0/clip.pitch+1500.0;
    if(maxMs>12000.0) maxMs=12000.0;
    while(!clip.finished){
        if((double)(GetTickCount()-startTick)>maxMs) break;
        Sleep(5);
    }
    Sleep(120);

    ma_device_uninit(&device);
    free(pcm);
    ma_context_uninit(&ctx);
    return 0;
}

static int do_probe(const wchar_t *wOut){
    ma_context ctx;
    ma_device_info *pPlayback=NULL,*pCapture=NULL;
    ma_uint32 playbackCount=0,captureCount=0,i;
    const char *dsName=""; const char *defName="";
    int dsPresent=0,defHeadphones=0,haveDefault=0;
    FILE *f;
    if(ma_context_init(NULL,0,NULL,&ctx)==MA_SUCCESS){
        if(ma_context_get_devices(&ctx,&pPlayback,&playbackCount,&pCapture,&captureCount)==MA_SUCCESS){
            for(i=0;i<playbackCount;++i){
                const char *nm=pPlayback[i].name;
                if(!dsPresent&&looks_like_controller(nm)){ dsPresent=1; dsName=nm; }
                if(pPlayback[i].isDefault){ defName=nm; haveDefault=1; }
            }
            if(haveDefault) defHeadphones=looks_like_headphones(defName);
        }
    }
    f=_wfopen(wOut,L"wb");
    if(f){
        fprintf(f,"dualsense_present=%d\n",dsPresent);
        fprintf(f,"dualsense_name=%s\n",dsName);
        fprintf(f,"default_name=%s\n",defName);
        fprintf(f,"default_is_headphones=%d\n",defHeadphones);
        fclose(f);
    }
    ma_context_uninit(&ctx);
    return 0;
}

int WINAPI WinMain(HINSTANCE hI, HINSTANCE hP, LPSTR lpCmd, int nShow){
    int argc=0,rc=1; LPWSTR *argv;
    (void)hI;(void)hP;(void)lpCmd;(void)nShow;
    argv=CommandLineToArgvW(GetCommandLineW(),&argc);
    if(!argv) return 1;
    if(argc>=2 && _wcsicmp(argv[1],L"play")==0 && argc>=5){
        int vol  =(argc>=6)?_wtoi(argv[5]):90;
        int pitch=(argc>=7)?_wtoi(argv[6]):100;
        rc=do_play(argv[2],argv[3],vol,pitch);
    } else if(argc>=3 && _wcsicmp(argv[1],L"probe")==0){
        rc=do_probe(argv[2]);
    } else {
        rc=64;
    }
    LocalFree(argv);
    return rc;
}
