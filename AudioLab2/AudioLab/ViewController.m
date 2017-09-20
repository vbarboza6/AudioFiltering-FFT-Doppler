//
//  ViewController.m
//  AudioLab
//
//  Created by Eric Larson
//  Copyright © 2016 Eric Larson. All rights reserved.
//

#import "ViewController.h"
#import "Novocaine.h"
#import "CircularBuffer.h"
#import "SMUGraphHelper.h"
#import "FFTHelper.h"
#import "AudioFileReader.h"

#define BUFFER_SIZE 2048*4

@interface ViewController ()
@property (strong, nonatomic) Novocaine *audioManager;
@property (strong, nonatomic) CircularBuffer *buffer;
@property (strong, nonatomic) SMUGraphHelper *graphHelper;
@property (strong, nonatomic) FFTHelper *fftHelper;
@property (strong, nonatomic) AudioFileReader *fileReader;
@property (nonatomic) NSInteger frequencyOne;
@property (nonatomic) NSInteger frequencyTwo;
@property (weak, nonatomic) IBOutlet UILabel *labelOne;
@property (weak, nonatomic) IBOutlet UILabel *labelTwo;

@end



@implementation ViewController

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
                                                       numGraphs:3
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

-(AudioFileReader*)fileReader{
    if(!_fileReader){
        NSURL *inputFileURL = [[NSBundle mainBundle] URLForResource:@"satisfaction" withExtension:@"mp3"];
        _fileReader = [[AudioFileReader alloc]
                       initWithAudioFileURL:inputFileURL
                       samplingRate:self.audioManager.samplingRate
                       numChannels:self.audioManager.numOutputChannels];
    }
    return _fileReader;
}


#pragma mark VC Life Cycle
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    
    [self.graphHelper setScreenBoundsBottomHalf];
    
    
    __block ViewController * __weak  weakSelf = self;
    
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

#pragma mark GLK Inherited Functions
//  override the GLKViewController update function, from OpenGLES
- (void)update{
    // just plot the audio stream
    
    // get audio stream data
    float* arrayData = malloc(sizeof(float)*BUFFER_SIZE);
    float* maximum = malloc(sizeof(float)*20);
    NSMutableArray *indexes = [NSMutableArray array];
    float* fftMagnitude = malloc(sizeof(float)*BUFFER_SIZE/2);
    
    // Find max for maximum array
    
    NSInteger windowLength = 49;
    NSInteger fftSize = (BUFFER_SIZE/2) - 49;
    
    for(int k = 0; k < fftSize; k++){
        
        NSMutableArray *tempBatch = [NSMutableArray arrayWithCapacity:windowLength];
        
        for(int i = 0; i <= windowLength; i++){
            
            NSNumber * number = [[NSNumber alloc] initWithFloat:fftMagnitude[i+k]];
            [tempBatch addObject:number];
        }
        
        NSNumber * medianNumber = [[NSNumber alloc] initWithFloat:fftMagnitude[25]];
        NSNumber *maxNumber = [tempBatch valueForKeyPath:@"@max.self"];
        
        if(medianNumber == maxNumber){
            maximum[k] = [maxNumber floatValue];
            [indexes addObject:[NSNumber numberWithInteger:k]];
        }

    }
    _frequencyOne = ((int)[indexes objectAtIndex:0] * 44100) / 512;
    _frequencyTwo = ((int)[indexes objectAtIndex:0] * 44100) / 512;
    
    self.labelOne.text = [NSString stringWithFormat: @"%ld",(long)_frequencyOne];
    self.labelTwo.text = [NSString stringWithFormat: @"%ld",(long)_frequencyTwo];
    
   
    free(arrayData);
    free(maximum);
    free(fftMagnitude);
}

//  override the GLKView draw function, from OpenGLES
- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    [self.graphHelper draw]; // draw the graph
}


@end
