//
//  ModuleBViewController.m
//  AudioLab
//
//  Created by Elena Sharp on 9/18/17.
//  Copyright © 2017 Eric Larson. All rights reserved.
//

#import "ModuleBViewController.h"
#import "Novocaine.h"
#import "CircularBuffer.h"
#import "SMUGraphHelper.h"
#import "FFTHelper.h"

#define BUFFER_SIZE 2048*4

@interface ModuleBViewController ()
@property (nonatomic) float frequency;
@property (weak, nonatomic) IBOutlet UILabel *freqLabel;
@property (weak, nonatomic) IBOutlet UILabel *gestureLabel;
@property (strong, nonatomic) Novocaine* audioManager;
@property (nonatomic) float phaseIncrement;
@property (strong, nonatomic) CircularBuffer *buffer;
@property (strong, nonatomic) SMUGraphHelper *graphHelper;
@property (strong, nonatomic) FFTHelper *fftHelper;
@end

@implementation ModuleBViewController
#pragma mark Lazy Instantiation
-(Novocaine*)audioManager{
    if(!_audioManager){
        _audioManager = [Novocaine audioManager];
    }
    return _audioManager;
}

-(CircularBuffer*)buffer{
    if(!_buffer){
        _buffer = [[CircularBuffer alloc]initWithNumChannels:1 andBufferSize:BUFFER_SIZE];
    }
    return _buffer;
}

-(SMUGraphHelper*)graphHelper{
    if(!_graphHelper){
        _graphHelper = [[SMUGraphHelper alloc]initWithController:self
                                        preferredFramesPerSecond:15
                                                       numGraphs:1
                                                       plotStyle:PlotStyleSeparated
                                               maxPointsPerGraph:BUFFER_SIZE];
    }
    return _graphHelper;
}

-(FFTHelper*)fftHelper{
    if(!_fftHelper){
        _fftHelper = [[FFTHelper alloc]initWithFFTSize:BUFFER_SIZE];
    }
    
    return _fftHelper;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.graphHelper setScreenBoundsBottomHalf];
    
    __block ModuleBViewController * __weak  weakSelf = self;
    
    [self updateFrequencyInKhz:15]; // Start at 15 khz
    
    self.phaseIncrement = 2*M_PI*self.frequency/self.audioManager.samplingRate;
    __block float phase = 0.0;
    [self.audioManager setOutputBlock:^(float* data, UInt32 numFrames, UInt32 numChannels){
        for(int i=0;i<numFrames;i++){
            for(int j=0;j<numChannels;j++){
                data[i*numChannels+j] = sin(phase);
            }
            phase += self.phaseIncrement;
            
            if(phase>2*M_PI){
                phase -= 2*M_PI;
            }
        }
        
        
    }];
    
    [self.audioManager setInputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels){
        [weakSelf.buffer addNewFloatData:data withNumSamples:numFrames];
    }];
    
    [self.audioManager play];
    
}
- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    if ([self.audioManager playing]){
        [self.audioManager pause];
    }
}

- (IBAction)frequencyChanged:(UISlider *)sender {
    [self updateFrequencyInKhz:sender.value];
    
}

-(void)updateFrequencyInKhz:(float) freqInKHz {
    self.frequency = freqInKHz*1000.0;
    self.freqLabel.text = [NSString stringWithFormat:@"%.4f kHz",freqInKHz];
    self.phaseIncrement = 2*M_PI*self.frequency/self.audioManager.samplingRate;
}

#pragma mark GLK Inherited Functions
//  override the GLKViewController update function, from OpenGLES
- (void)update{
    // just plot the audio stream
    
    // get audio stream data
    float* arrayData = malloc(sizeof(float)*BUFFER_SIZE);
    float* fftMagnitude = malloc(sizeof(float)*BUFFER_SIZE/2);
    
    [self.buffer fetchFreshData:arrayData withNumSamples:BUFFER_SIZE];
    
    // take forward FFT
    [self.fftHelper performForwardFFTWithData:arrayData
                   andCopydBMagnitudeToBuffer:fftMagnitude];
    
    // Get the index for the current pitch being played
    int indexNum = (self.frequency * BUFFER_SIZE)/[self.audioManager samplingRate];
    
    float pitchMagnitude = fftMagnitude[indexNum] + 64;
    float leftMagnitude = fftMagnitude[indexNum-3] + 64;
    float rightMagnitude = fftMagnitude[indexNum+3] + 64;
    
//    if(fabsf(rightMagnitude/pitchMagnitude) > .9){
//        self.gestureLabel.text = @"Gestures Toward Intense";
//        [self.navigationController popViewControllerAnimated:YES];
//    }
    if(fabsf(leftMagnitude/pitchMagnitude) > .6){
        self.gestureLabel.text = @"Gestures away";
    }
    else if(fabsf(rightMagnitude/pitchMagnitude) > .6){
        self.gestureLabel.text = @"Gestures Toward";
    }
    else{
        self.gestureLabel.text = @"No Gesture";
    }
    
    // graph the FFT Data
    [self.graphHelper setGraphData:fftMagnitude
                    withDataLength:BUFFER_SIZE/2
                     forGraphIndex:0
                 withNormalization:64.0
                     withZeroValue:-60];

    
    [self.graphHelper update]; // update the graph
    free(arrayData);
    free(fftMagnitude);
}

//  override the GLKView draw function, from OpenGLES
- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    [self.graphHelper draw]; // draw the graph
}



@end
