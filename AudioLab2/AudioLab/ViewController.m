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
@property (nonatomic) float frequencyOne;
@property (nonatomic) float frequencyTwo;
@property (nonatomic) float lockedFrequencyOne;
@property (nonatomic) float lockedFrequencyTwo;
@property (strong, nonatomic)NSMutableArray *maximum;
@property (strong, nonatomic)NSMutableArray *indexes;
@property (weak, nonatomic) IBOutlet UILabel *freqLabelOne;
@property (weak, nonatomic) IBOutlet UILabel *freqLabelTwo;

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

-(NSMutableArray*)maximum{
    if(!_maximum){
        _maximum = [NSMutableArray array];
    }
    return _maximum;
}

-(NSMutableArray*)indexes{
    if(!_indexes){
        _indexes = [NSMutableArray array];
    }
    return _indexes;
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
    float* fftMagnitude = malloc(sizeof(float)*BUFFER_SIZE/2);
//    NSMutableArray *maximum = [NSMutableArray array];
//    NSMutableArray *indexes = [NSMutableArray array];
    NSMutableArray *fftData = [NSMutableArray array];
    
    
    [self.buffer fetchFreshData:arrayData withNumSamples:BUFFER_SIZE];
    
    // take forward FFT
    [self.fftHelper performForwardFFTWithData:arrayData
                   andCopydBMagnitudeToBuffer:fftMagnitude];
    

    
    NSInteger windowLength = 5;
    NSInteger fftBufferSize = BUFFER_SIZE/2;
    NSInteger fftSize = (BUFFER_SIZE/2) - 5;
    
    for(int k = 4; k < fftSize; k++){
        
        NSMutableArray *tempBatch = [NSMutableArray arrayWithCapacity:windowLength];
        [fftData addObject:[NSNumber numberWithFloat: fftMagnitude[k]]];
        
        for(int i = 0; i <= windowLength; i++){
          
            NSNumber * number = [[NSNumber alloc] initWithFloat:fftMagnitude[i+k]];
            [tempBatch addObject:number];
        }
        
        NSNumber * medianNumber = [tempBatch objectAtIndex:3];
        NSNumber *maxNumber = [tempBatch valueForKeyPath:@"@max.self"];
        
        if(medianNumber == maxNumber){
            
            if([self.maximum count] < 2 ){
                [self.maximum addObject: maxNumber];
                [self.indexes addObject:[NSNumber numberWithInt:k]];
            }
            else{
                if([maxNumber floatValue] > (float)-15){
                    if([maxNumber floatValue] > [[self.maximum objectAtIndex:0] floatValue]){
                        [self.maximum replaceObjectAtIndex:0 withObject: maxNumber];
                        [self.indexes replaceObjectAtIndex:0 withObject:[NSNumber numberWithInt:k]];
                    }
                    if([maxNumber floatValue] > [[self.maximum objectAtIndex:1] floatValue] && [maxNumber floatValue] != [[self.maximum objectAtIndex:0] floatValue] ){
                        [self.maximum replaceObjectAtIndex:1 withObject:maxNumber];
                        [self.indexes replaceObjectAtIndex:1 withObject:[NSNumber numberWithInt:k]];
                    }
                }
            }
        }

    }
    
//    NSNumber *trueMaxNumber = [fftData valueForKeyPath:@"@max.self"];
//    NSSet *numberSet = [NSSet setWithArray:fftData];
//    
//    NSArray *sortedNumbers = [[numberSet allObjects] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"self" ascending:NO] ]];
//    
//    NSNumber *secondHighest;
//    
//    if ([sortedNumbers count] > 1){
//        secondHighest = sortedNumbers[1];
//    }
//    
//    long index1 = [fftData indexOfObject:trueMaxNumber];
//    long index2 = [fftData indexOfObject:secondHighest];
    
    
    long index1 = [[self.indexes objectAtIndex:0] longValue];
    long index2 = [[self.indexes objectAtIndex:1] longValue];
    
    NSNumber *secondHighest = [self.maximum objectAtIndex:0];
    NSNumber *trueMaxNumber = [self.maximum objectAtIndex:1];

    int fpeak1 = 0;
    int fpeak2 = 0;
    
    if(index1 > 0 && index2 > 0){
        
        long indexleft1 = index1 - 1;
        long indexright1 = index1 + 1;
        long indexleft2 = index2 - 1;
        long indexright2 = index2 + 1;
        
        float mOneLeft = [[fftData objectAtIndex:indexleft1] floatValue];
        float mOneRight = [[fftData objectAtIndex:indexright1] floatValue];
        float mTwoLeft = [[fftData objectAtIndex:indexleft2] floatValue];
        float mTwoRight = [[fftData objectAtIndex:indexright2] floatValue];
        
        fpeak1 = index1 + ((mOneRight - [trueMaxNumber floatValue]) / ((2 * [trueMaxNumber floatValue]) - mOneLeft - [trueMaxNumber floatValue])) * ((44100/fftBufferSize)/2);
        fpeak2 = index2 + ((mTwoRight - [secondHighest floatValue]) / ((2 * [secondHighest floatValue]) - mTwoLeft - [secondHighest floatValue])) * ((44100/fftBufferSize)/2);
    }
    
    
    _frequencyOne = (fpeak1 * ([self.audioManager samplingRate] / fftBufferSize)) / 2;
    _frequencyTwo = (fpeak2 * ([self.audioManager samplingRate] / fftBufferSize)) / 2;
    
    self.freqLabelOne.text = [NSString stringWithFormat:@"%.2f Hz : %@",_frequencyOne, trueMaxNumber];
    self.freqLabelTwo.text = [NSString stringWithFormat:@"%.2f Hz : %@",_frequencyTwo, secondHighest];
    
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
