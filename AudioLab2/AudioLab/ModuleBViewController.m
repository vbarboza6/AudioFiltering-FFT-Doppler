//
//  ModuleBViewController.m
//  AudioLab
//
//  Created by Elena Sharp on 9/18/17.
//  Copyright © 2017 Eric Larson. All rights reserved.
//

#import "ModuleBViewController.h"
#import "Novocaine.h"

#define BUFFER_SIZE 2048*4

@interface ModuleBViewController ()
@property (nonatomic) float frequency;

@property (weak, nonatomic) IBOutlet UILabel *freqLabel;

@property (strong, nonatomic) Novocaine* audioManager;

@property (nonatomic) float phaseIncrement;
@end

@implementation ModuleBViewController

-(Novocaine*)audioManager{
    if(!_audioManager){
        _audioManager = [Novocaine audioManager];
    }
    return _audioManager;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self updateFrequencyInKhz:0.2616255]; // mid C
    
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


@end
