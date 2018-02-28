%% reference from RTL_SDR book

offline          = input('type 0 for RTL-SDR 1 to use captured file(following Lab6 discriminator ');     % 0 = use RTL-SDR, 1 = import data
rtlsdr_id        = '0';                          % stick ID
if offline == 0
rtlsdr_fc        = input('frquency in Hz ');                      % tuner centre frequency in Hz
end
rtlsdr_gain      = 50;                          % tuner gain in dB
rtlsdr_fs        = 2.4e6;                       % tuner sampling rate
rtlsdr_ppm       = 0;                           % tuner parts per million correction
rtlsdr_frmlen    = 256*25;                      % output data frame size (multiple of 5)
rtlsdr_datatype  = 'single';                    % output data type
deemph_region 	 = 'eu';                        % set to either eu or us
audio_fs         = 48e3;                        % audio output sampling rate
sim_time         = 60;                          % simulation time in seconds

%% CALCULATIONS (do not edit)
% calculations regarding de-emphasizer
rtlsdr_frmtime = rtlsdr_frmlen/rtlsdr_fs;       % calculate time for 1 frame of data
if deemph_region == 'eu'                        % find de-emphasis filter coeff
    [num,den] = butter(1,3183.1/(audio_fs/2));  % butterworth filter
elseif deemph_region == 'us'
    [num,den] = butter(1,2122.1/(audio_fs/2));
else
    error('Invalid region for de-emphasis filter - must be either "eu" or "us"');
end
%% capturng FM signals using RTLdongle
if offline == 0
obj_rtlsdr = comm.SDRRTLReceiver(...
        rtlsdr_id,...
        'CenterFrequency', rtlsdr_fc,...
        'EnableTunerAGC', false,...
        'TunerGain', rtlsdr_gain,...
        'SampleRate', rtlsdr_fs, ...
        'SamplesPerFrame', rtlsdr_frmlen,...
        'OutputDataType', rtlsdr_datatype,...
        'FrequencyCorrection', rtlsdr_ppm);
    
    % fir decimator - fs = 2.4MHz downto 48kHz
    obj_decmtr = dsp.FIRDecimator(...
        'DecimationFactor', 50,...
        'Numerator', firpm(350,[0,15e3,48e3,(2.4e6/2)]/(2.4e6/2),...
        [1 1 0 0], [1 1], 20));
    
    
% iir de-emphasis filter
obj_deemph = dsp.IIRFilter(...
    'Numerator', num,...
    'Denominator', den);

% delay
obj_delay = dsp.Delay;

% audio output
obj_audio = dsp.AudioPlayer(audio_fs);

% reset run_time to 0 (secs)
run_time = 0;

% loop while run_time is less than sim_time
while run_time < sim_time
    
    % fetch a frame from obj_rtlsdr (live or offline)
    rtlsdr_data = step(obj_rtlsdr);
    
    % implement frequency discriminator
    discrim_delay = step(obj_delay,rtlsdr_data);
    discrim_conj  = conj(rtlsdr_data);
    discrim_pd    = discrim_delay.*discrim_conj;
    discrim_arg   = angle(discrim_pd);
    
    % decimate + de-emphasis filter data
    data_dec = step(obj_decmtr,discrim_arg);
    data_deemph = step(obj_deemph,data_dec);
    
    % update 'demodulated' spectrum analyzer window with new data
%     step(obj_spectrumdemod, data_deemph);
    % output demodulated signal to speakers
    step(obj_audio,data_deemph);
    
    % update run_time after processing another frame
    run_time = run_time + rtlsdr_frmtime;
    
end

else 
    y = loadFile('FM_capturenew.dat');
    %% demodulation
% plotting captured signal
plot_FFT_IQ(y,1,.002*2.5E6,2.5,106.3)
%This function demodualtes an FM signal. It is assumed that the FM signal
%is complex (i.e. an IQ signal) centered at DC and occupies less than 90%
%of total bandwidth. 
% implementing a fir least squares 
b = firls(30,[0 .9],[0 1],'differentiator'); %design differentiater 
d=y./abs(y);
%normalize the amplitude (i.e. remove amplitude variations) 
rd=real(d); 
%real part of normalized siganl. 
id=imag(d); %imaginary part of normalized signal. 
y_FM_demodulated=(rd.*conv(id,b,'same')-id.*conv(rd,b,'same'))./(rd.^2+id.^2); %demodulate!
% end
% demodulated signal plotting it
df = decimate(y_FM_demodulated,10,'fir');
plot_FFT_IQ(y_FM_demodulated,1,.05*2.5E6/8,2.5/8,0,'Spectrum of demodulated signal')
% plot further decimation for sound card of laptop Fs should 15kHz
% sound(df,2.5E6/8/10/2);
end
    