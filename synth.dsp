import("music.lib");
//ml = library("music.lib");  // SR, ...
oscillator = library("oscillator.lib");
fl = library("filter.lib");
instrument = library("instrument.lib");
maxmsp = library("maxmsp.lib");
effect = library("effect.lib");
music = library("music.lib");

import("fast.lib");

voicecount = 4;

halftime2fac(x) = 0.5^(1./(SR*x));
halftime2fac_fast(x) = 1-0.7*(1./(SR*x));

//smooth(c)        = *(1-c) : +~*(c);
smooth(x) = maxmsp.line(x,2);

envdecay(c) = (max:_ * c) ~ _;

dotpart(x) = x - int(x);

oscss(freq, even_harm) = even_harm*saw-(1-even_harm)*square
with {
    square = oscillator.lf_squarewave(freq)*0.5;
    saw = oscillator.saw2(freq);
};

note = vslider("[0]note[style:knob]",69,0,127,.01);
pres = vslider("[1]pres[style:knob]",0,0,1,0.01);
vpres = vslider("[2]vpres[style:knob]",0,-1,1,0.01);
but_x = vslider("but_x[style:knob]",0,-1,1,0.01);
but_y = vslider("but_y[style:knob]",0,-1,1,0.01);

acc_abs = vslider("v:accelerometer/acc_abs[style:knob]",1,0,4,0.01) : LPF(K_f0(40),1.31) : LPF(K_f0(40),0.54);
acc_x = vslider("v:accelerometer/acc_x[style:knob]",0,-1,1,0.01);
acc_y = vslider("v:accelerometer/acc_y[style:knob]",0,-1,1,0.01);
acc_z = vslider("v:accelerometer/acc_z[style:knob]",-1,-1,1,0.01);

rot_x = vslider("v:gyroscope/rot_x[style:knob]",0,-1,1,0.01);
rot_y = vslider("v:gyroscope/rot_y[style:knob]",0,-1,1,0.01);
rot_z = vslider("v:gyroscope/rot_z[style:knob]",0,-1,1,0.01);

posDecay = hslider("v:[0]config/posDecay[style:knob]",0.1,0,1,0.01):halftime2fac;
negDecay = hslider("v:[0]config/negDecay[style:knob]",0.2,0,1,0.01):halftime2fac;
pDecay = hslider("v:[0]config/pDecay[style:knob]",0.05,0,1,0.01):halftime2fac;
accDecay = hslider("v:[0]config/accDecay[style:knob]",0.10,0,1,0.01):halftime2fac;

wpos = hslider("v:[0]config/wpos[style:knob]",0.05,0,1,0.01);
wneg = hslider("v:[0]config/wneg[style:knob]",0.0,0,1,0.01);
wpres = hslider("v:[0]config/wpres[style:knob]",0.9,0,1,0.01);

filtQ = hslider("v:[1]config2/filtQ[style:knob]",1,0,10,0.01);
filtFF = hslider("v:[1]config2/filtFF[style:knob]",1,0,16,0.01);
bendRange = hslider("v:[1]config2/bendRange[style:knob]",0.5,0,2,0.01);
minFreq = hslider("v:[1]config2/minFreq[style:knob]",200,0,1000,1);
bodyFreq = hslider("v:[1]config2/bodyFreq[style:knob]",1000,0,2000,1);
filt2Freq = hslider("v:[1]config2/filt2Freq[style:knob]",3000,0,10000,1);
filt2Q = hslider("v:[1]config2/filt2Q[style:knob]",2,0.01,10,0.01);
filt2level = hslider("v:[1]config2/filt2Level[style:knob]",0.8,0,50,0.01);

B = hslider("v:[2]config3/brightness[style:knob]", 0.5, 0, 1, 0.01);// 0-1
t60 = hslider("v:[2]config3/decaytime_T60[style:knob]", 10, 0, 10, 0.01);  // -60db decay time (sec)
resfact = hslider("v:[2]config3/resfact[style:knob]", 0.03, 0, 1, 0.01);
ppOffset = hslider("v:[2]config3/ppOffset[style:knob]", 48, 0, 100, 0.1);
ppRange = hslider("v:[2]config3/ppRange[style:knob]", 18, 0, 36, 0.1);

bfQ = hslider("v:[2]config3/bfQ[style:knob]",8,0,20,0.01);

voice(note,pres,vpres,but_x,but_y) = vosc <: filt, filt2 :> _ * level
with {
    even_harm = (acc_x+1)/2;
    pitchbend = but_x^3;
    freq = note2freq(note+pitchbend*bendRange);
    //vosc = oscss(freq, even_harm);
    vosc = osc_white(freq);
    resetni = abs(note-note')<1.0;

    pluck = but_y^2 : envdecay(select2(pres==0, halftime2fac_fast(0.02), 1));
    //decaytime = max(max(min(pluck * 8 - 0.4, 0.5+pluck), min(pres * 16, 0.5+pres)), 0.05) * 64 / note;
    decaytime = max(min(pres * 16, 0.5+pres*0.5), 0.05) * 64 / note;
    vpres1 = max(vpres - 0.001, 0);
    vplev = vpres1 / (0.5+vpres1) + 0.6 * max(pres-0.3,0)^2;// + min(pres, 0.001);
    rotlev = min(pres * 2, max(rot_y^2+rot_z^2 - 0.005, 0));
    level = max(vplev : envdecay(resetni*halftime2fac_fast(decaytime)), rotlev) : LPF(K_f0(100), 1);// / (0.2 + note/24);

    vdacc = min(acc_abs,2):envdecay(accDecay);
    K = K_f0(max(freq,minFreq)) + filtFF*(level*(1-max(-but_y,0))+max(vdacc-1,0))^2^2;
    filt = LPF(K, filtQ+max(-but_y,0)*8) * (1-max(-but_y,0)/2)^2;

    filt2lev = max(but_y,0) * but_y * pres;
    filt2 = BPF(K_f0(filt2Freq*filt2lev+minFreq), filt2Q) * filt2level * filt2lev;

    K1 = select2(rot_y>0, K_f0(7000), K_f0(3000)) * (1+0.5*abs(rot_y));
    b1 = BPF(K1, bfQ) * (rot_y^2);
    K2 = select2(rot_z>0, K_f0(5000), K_f0(2000)) * (1+0.5*abs(rot_z));
    b2 = BPF(K2, bfQ) * (rot_z^2);
    bfs = _ <: b1, b2 :> _;
};

voice_sine(note,pres,vpres,but_x,but_y) = vosc * level
with {
    pitchbend = but_x^3;
    freq = note2freq(note+pitchbend*bendRange);
    vosc = oscillator.oscw(freq);
    level = pres : LPF(K_f0(20),1);
};

/*
peak(f0, dBgain, Q) = biquad(a0,a1,a2,b1,b2)
    with {
        V = 10^(abs(dBgain) / 20);
        K = tan(PI * f0 / SR);

        if (peakGain >= 0) {
            norm = 1 / (1 + 1/Q * K + K * K);
            a0 = (1 + V/Q * K + K * K) * norm;
            a1 = 2 * (K * K - 1) * norm;
            a2 = (1 - V/Q * K + K * K) * norm;
            b1 = a1;
            b2 = (1 - 1/Q * K + K * K) * norm;
        }
        else {
            norm = 1 / (1 + V/Q * K + K * K);
            a0 = (1 + 1/Q * K + K * K) * norm;
            a1 = 2 * (K * K - 1) * norm;
            a2 = (1 - 1/Q * K + K * K) * norm;
            b1 = a1;
            b2 = (1 - V/Q * K + K * K) * norm;
        }
    }
*/

seed = 1034790774; // no. 62351 in sequence
impulse = _ ~ (_ == 0);
//myrandom = (+(seed + 12345) *(1103515245)) ~ (-(seed));
//myrandom = +(seed + 12345) ~ (*(1103515245) -(seed));
//myrandom = seed : impulse : (_,_: + : +(12345)) ~ *(1103515245);
//myrandom = (+(12345) *(1103515245)) ~ _;
//myrandom = (impulse(seed-12345) + 12345) : + ~ (*(1103515245));
//RANDMAX = 2147483647.0;

//myrandom = prefix(seed,0) : + ~ (*(1078318381));
myrandom = ffunction(int rand_hoaglin (), "fastpow.h", "");

mynoise = myrandom / RANDMAX;

// offset to improve spectral shape
o = 0;//320;//int(hslider("v:[2]config3/offset[style:knob]", 0, 0, 1<<11, 1));
osc_white1(freq) = s1 + d * (s2 - s1)
with {
    tablesize = 1 << 12; // enough for notes as low as 11 Hz
    whitetable = rdtable(tablesize, mynoise*2);
    periodf = float(SR)/freq;
    period = int(min(periodf * 0.5, tablesize));
    inc = period/periodf;
    loop = _ <: _,((_ > period) * period) :> -;
    phase = inc : (+ : loop) ~ _;
    s1 = whitetable(o + int(phase));
    s2 = whitetable(o + ((int(phase)+1) % int(period)));
    d = dotpart(phase);
};

// osc_white = oscillator.saw2;
osc_white = osc_white1;

// white oscilator test to reduce clicks on frequency change
inco = hslider("v:[2]config3/inc[style:knob]", 1, 0, 2, 0.01);
osc_white2(freq) = s1 + d * (s2 - s1)
with {
    tablesize = 1 << 12; // enough for notes as low as 11 Hz
    whitetable = rdtable(tablesize, noise*2);
    periodf = float(SR)/freq;
    inc = inco;
    period = periodf*inc;
    loop = _ <: _,((_ > period) * period) :> -;
    phase = inc : (+ : loop) ~ _;
    s1 = whitetable(o + int(phase));
    s2 = whitetable(o + ((int(phase)+1) % int(period)));
    jump = phase > int(period);
    d = select2(jump, dotpart(phase), dotpart(phase) / dotpart(period));
    //d = dotpart(phase) * 1.0/dotpart(period);
};

// Body Filter
bodyFilter = _ <: _ * .7,LPF(K_f0(bodyFreq),0.3) * 2 :> _;

mystereoizer(periodDuration) = _ <: _,widthdelay : stereopanner
with {
    W = 0.5; //hslider("v:Spat/spatial width", 0.5, 0, 1, 0.01);
    A = 0.5; //hslider("v:Spat/pan angle", 0.6, 0, 1, 0.01);
    widthdelay = delay(4096,W*periodDuration/2);
    stereopanner = _,_ : *(1.0-A), *(A);
};

stereo = mystereoizer(SR/440);

vmeter(x) = attach(x, envelop(x) : vbargraph("[2]level", 0, 1));
envelop = abs : max ~ -(20.0/SR);

process = hgroup("strisy",
        sum(n, voicecount, vgroup("v%n", (note,pres,vpres,but_x,but_y)) : voice) // : vgroup("v%n", vmeter))
        : HPF(K_f0(80),1.31) );// : fl.dcblocker;: stereo:bodyFilter;