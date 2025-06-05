// Gui
// variables globales

~capa = 1;
~numSpeakers = 2;
~firstOut = 0;

// flag del canon
~canonF = true;


~patrones = Array.newClear(9);
~pitchM = [];
~durM= [];
~markP = [];
~markD = [];

// cargar sonidos:
"syndefs.scd".loadRelative;

// detectores
SynthDef(\detectaAmps, {|in = 0, umbral = 0.5|
	var inp, onsets, chain, amp, pich, hasPich;
	inp = SoundIn.ar(in);
	amp  = Amplitude.kr(inp, 0.01, 1);
	SendReply.kr(Impulse.kr(20), '/amplis', amp);
}).add;

SynthDef(\detectaPich, {|in = 0|
	var inp, pich, hasPich;
	inp = SoundIn.ar(in);
	#pich, hasPich = Pitch.kr(inp);
	SendReply.kr(Impulse.kr(20), '/alturas', pich);
}).add;

SynthDef(\detectaAtaque, {|in = 0, umbral = 0.5|
	var inp, chain, onsets;
	inp = SoundIn.ar(in);
	chain =  FFT(LocalBuf(512), inp);
    onsets = Onsets.kr(chain, umbral, \rcomplex, 1.5);
	SendTrig.kr(onsets, 0);
}).add;


// función de inicialización
~init = {
	~altura = 440;

	OSCdef(\detectP, {arg msg, time, addr, port;
		~altura = msg[3]
	}, '/alturas', s.addr).disable;

	~duraciones = [];
	~alturas= [];

	OSCdef(\detectPatt, {arg msg, time, addr, port;
		~duraciones = ~duraciones.add(time);
		~alturas = ~alturas.add(~altura);
		[time.round(0.1), ~altura.round(0.1)].postln;
	}, \tr, s.addr).disable;
};

~syns = [\reed, \melos, \bup, \plucking, \dx11, \bell, \piano_MDA];
~bt = Array.newClear(8);
w = Window(\markoyager, 500@300).front;
c = CompositeView(w, Rect(5, 5, 490, 290)).background_(Color.new255(104, 131, 139).vary(0.05, 0.35, 0.7));
c.decorator = FlowLayout(c.bounds);
c.decorator.margin = 2@2; c.decorator.gap = 2@2;
~font = Font("Optima-Regular", 25);
~bt[0] = Button(c, 200@150).states_([
	["detectar", Color.white, Color.red(0.7, 0.9)],
	["stop", Color.black, Color.yellow(0.7, 0.3)]
]).font_(~font);
c.decorator.shift(100, 0);
~bt[1] =PopUpMenu(c, 180@40).font_(~font);
~bt[1].items = ~syns;

c.decorator.nextLine;
c.decorator.shift(320, -110);
~bt[2] = Button(c, 150@100).states_([["play", Color.white, Color.blue(0.8, 0.8)]]).font_(~font);

c.decorator.nextLine;
c.decorator.shift(320, 0);
~bt[3] = Button(c, 150@50).states_([["stop", Color.black, Color.cyan(0.4, 0.8)]]).font_(~font);
~bt[3].action = { ~patrones[~capa].stop};
	//~playerActual.stop
~bt[0].action = {|b|
	if (b.value == 1) {
		\comienza.postln;
		~init.value;
		~s1 = Synth(\detectaAtaque, [\umbral, 0.53]);
		~s2 = Synth(\detectaPich);
		OSCdef(\detectP).enable;
		"tocar melodía".postln;
		OSCdef(\detectPatt).enable;
}{
		OSCdef(\detectPatt).disable;
		~s1.free; ~s2.free;
		\yaAcabe.postln;
	}
};

c.decorator.shift(-260, -100);
~bt[4] = Button(c, 100@50).states_([
	["canon", Color.black, Color.green(0.7, 0.9)],
	["simple", Color.black, Color.green(1, 0.8)]
]).font_(~font).action = {|b| if (b.value == 0) {~canonF = true} {~canonF = false}};

c.decorator.nextLine;
c.decorator.shift(320, 100);
~bt[5]= Button(c, 150@50).states_([["stopAll", Color.black, Color.magenta(0.7, 0.7)]]).font_(~font);

~bt[5].action = {~patrones.do{|x| x.stop}};

c.decorator.shift(-260, -52);
~lin = ControlSpec(1, 8, 'lin', 1, 1);
~bt[6] = EZNumber(c, 100@50, "capa",~lin, {}, ~capa, true).font_(~font);

~bt[6].action = {|b|~capa = b.value; };

~bt[2].action = {|b|
	if ( ~duraciones.isEmpty) {~duraciones = [1, 2]; ~alturas = [440, 550];};
	~durs= ~duraciones.differentiate[1..].round(0.1).reject{|x| x == 0.0}.abs;
	~pitches = ~alturas.cpsmidi.round(1);
// entrenar el markov:
	if (~canonF) {
		~int = (~pitches - ~pitches[0]);
		~inv = ~pitches[0] - ~int;
		~canon = ~pitches ++ ~pitches.reverse ++ (~inv+ 7) ++ (~inv+7).reverse;
	}{ ~canon =~pitches };
	~pitchM = ~pitchM.add(ShannonFinger.new.data = ~canon);
	~durM = ~durM.add(ShannonFinger.new.data = ~durs);
	~markP = ~markP.add(~pitchM.last.asStream(order: 1));
	~markD = ~markD.add(~durM.last.asStream(order: 1));
// patrón:
	~uno = Pbind(\instrument, ~bt[1].item,
		\midinote, ~markP.last,
		\dur, ~markD.last,
		\pan, -1,
		\out, ~firstOut + (~capa-1).fold2(~numSpeakers-1).abs
	);
	~playerActual = ~uno.play(quant:1);
	~patrones[~capa].stop;
	~patrones[~capa] = ~playerActual;

};