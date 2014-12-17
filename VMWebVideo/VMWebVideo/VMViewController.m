//
//  ViewController.m
//  VMWebVideo
//
//  Created by Mike Verderese on 12/12/14.
//  Copyright (c) 2014 VM Labs. All rights reserved.
//

#import "VMViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "VMWebVideoManager.h"

#define SCREEN_WIDTH [UIScreen mainScreen].bounds.size.width
#define SCREEN_HEIGHT [UIScreen mainScreen].bounds.size.height

@interface VMViewController ()

@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, strong) AVPlayerItem *playerItem;
@property (nonatomic, strong) NSURL *videoPath;

@property (strong, nonatomic) UIButton *startButton;
@property (strong, nonatomic) UIProgressView *progressView;

@end

@implementation VMViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    _player = [AVPlayer playerWithURL:nil];
    
    _playerLayer = [AVPlayerLayer playerLayerWithPlayer:_player];
    _player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    _playerLayer.videoGravity = AVLayerVideoGravityResize;
    _playerLayer.frame = CGRectMake(0, 144, SCREEN_WIDTH, SCREEN_WIDTH);
    _playerLayer.backgroundColor = [UIColor clearColor].CGColor;
    // _playerLayer.hidden = YES;
    [self.view.layer addSublayer:_playerLayer];
    
    _player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    
    
    self.startButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 44, SCREEN_WIDTH, 100)];
    self.startButton.contentMode = UIViewContentModeCenter;
    [self.startButton setTitle:@"Start download" forState:UIControlStateNormal];
    [self.startButton setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [self.startButton addTarget:self action:@selector(startDownlaod) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:self.startButton];
    
    self.progressView = [[UIProgressView alloc] initWithFrame:self.playerLayer.frame];
    self.progressView.hidden = YES;
    self.progressView.contentMode = UIViewContentModeCenter;
    [self.view addSubview:self.progressView];
}

- (void)startDownlaod {
    
    NSURL *url = [NSURL URLWithString:@"https://staging.gettagapp.com/api/1/files/download?file_url=tagapp-private/staging/tag/video/2014-12-16_16:03:59-1.mov"];
    
    self.progressView.hidden = NO;
    
    [[VMWebVideoManager sharedManager] downloadVideoWithURL:url options:0 progress:^(NSInteger receivedSize, NSInteger expectedSize) {
        self.progressView.progress = (double)receivedSize/(double)expectedSize;
    } completed:^(NSURL *videoDataFilePath, NSError *error, VMVideoCacheType cacheType, BOOL finished, NSURL *videoURL) {
        if(!error && videoDataFilePath) {
            self.playerItem = [AVPlayerItem playerItemWithURL:videoDataFilePath];
            [_player replaceCurrentItemWithPlayerItem:self.playerItem];
            [self.player play];
        } else {
            [[[UIAlertView alloc] initWithTitle:@"Something went wrong"
                                        message:[error localizedDescription]
                                       delegate:nil
                              cancelButtonTitle:@"Okay"
                              otherButtonTitles:nil] show];
        }
    }];

}

@end
