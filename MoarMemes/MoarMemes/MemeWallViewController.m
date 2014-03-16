//
//  MemeWallViewController.m
//  MoarMemes
//
//  Created by Vova Galchenko on 3/15/14.
//  Copyright (c) 2014 Galchenko. All rights reserved.
//

#import "MemeWallViewController.h"
#import "ImgurImage.h"
#import <InfiniteScroll/INFNetworkImageScrollViewTile.h>
#import <InfiniteScroll/INFScrollView.h>
#import <MBProgressHUD/MBProgressHUD.h>

#define IMGUR_AUTHORIZATION_HEADER_VALUE        @"Client-ID 48a34159f0c434f"
#define IMGUR_METADATA_FETCH_URL                @"https://api.imgur.com/3/gallery/g/memes/viral/%d.json"
#define IMGUR_METADATA_FETCH_TIMEOUT_INTERVAL   10.0
#define IMGUR_METADATA_PAGES_TO_FETCH           20
#define IMGUR_METADATA_PAGE_NUM_TRIES           3

@interface MemeWallViewController ()

@property (weak, nonatomic) IBOutlet INFScrollView *infScrollView;
@property (nonatomic, readwrite, strong) NSMutableArray *imgurImages;

@end

@implementation MemeWallViewController

- (id)init
{
    self = [super initWithNibName:@"MemeWallViewController" bundle:[NSBundle mainBundle]];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self loadImageMetadata];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

static NSURL *imgurMetadataFetchURL(NSUInteger pageNum)
{
    return [NSURL URLWithString:[NSString stringWithFormat:IMGUR_METADATA_FETCH_URL, pageNum]];
}

static BOOL markPageLoaded(NSMutableDictionary *pages, NSUInteger pageIndex, BOOL loadSuccessful, __weak INFScrollView *scrollViewToReload, MBProgressHUD *hud)
{
    @synchronized(scrollViewToReload)
    {
        BOOL shouldRetry = NO;
        NSNumber *key = @(pageIndex);
        if (loadSuccessful)
        {
            [pages removeObjectForKey:key];
        }
        else
        {
            NSInteger numRetriesLeft = [pages[key] intValue] - 1;
            if (numRetriesLeft <= 0)
            {
                [pages removeObjectForKey:key];
            }
            else
            {
                [pages setObject:@(numRetriesLeft) forKey:key];
                shouldRetry = YES;
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^
        {
            hud.progress = 1.0 - (float)pages.count/(float)IMGUR_METADATA_PAGES_TO_FETCH;
        });
        if (pages.count == 0)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [scrollViewToReload reloadData:NO];
                [hud hide:YES];
            });
        }
        return shouldRetry;
    }
}

- (void)loadImageMetadata
{
    NSMutableDictionary *pages = [NSMutableDictionary dictionaryWithCapacity:IMGUR_METADATA_PAGES_TO_FETCH];
    if (!self.imgurImages)
        self.imgurImages = [NSMutableArray array];
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.mode = MBProgressHUDModeAnnularDeterminate;
    for (int i = 0; i < IMGUR_METADATA_PAGES_TO_FETCH; i++)
    {
        [pages setObject:@(IMGUR_METADATA_PAGE_NUM_TRIES) forKey:@(i)];
        [self loadImgurMetadataForPage:i pagesDictionary:pages hud:hud];
    }
}

- (void)loadImgurMetadataForPage:(int)i pagesDictionary:(NSMutableDictionary *)pages hud:(MBProgressHUD *)hud
{
    __block __weak NSMutableArray *imgurImages = self.imgurImages;
    __weak INFScrollView *scrollViewToReload = self.infScrollView;
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:imgurMetadataFetchURL(i)
                                                                cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                            timeoutInterval:IMGUR_METADATA_FETCH_TIMEOUT_INTERVAL];
    [request setValue:IMGUR_AUTHORIZATION_HEADER_VALUE forHTTPHeaderField:@"Authorization"];
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[[NSOperationQueue alloc] init]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError)
     {
         NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
         if (connectionError || httpResponse.statusCode != 200)
         {
             @synchronized(imgurImages)
             {
                 if (markPageLoaded(pages, i, NO, scrollViewToReload, hud))
                 {
                     [self loadImgurMetadataForPage:i pagesDictionary:pages hud:hud];
                 }
             }
         }
         else
         {
             NSError *jsonError = nil;
             NSDictionary *imgurResponse = [NSJSONSerialization JSONObjectWithData:data
                                                                           options:0
                                                                             error:&jsonError];
#warning handle json parse error
             @synchronized(imgurImages)
             {
                 for (NSDictionary *imgurMetadata in imgurResponse[@"data"])
                 {
                     [imgurImages addObject:[[ImgurImage alloc] initWithDictionary:imgurMetadata]];
                 }
                 markPageLoaded(pages, i, YES, scrollViewToReload, hud);
             }
         }
     }];
}

- (void)infiniteScrollView:(INFScrollView *)infiniteScrollView willUseInfiniteScrollViewTitle:(INFScrollViewTile *)tile atPositionHash:(NSInteger)positionHash
{
    if (self.imgurImages.count <= 0) return;
    [(INFNetworkImageScrollViewTile *)tile fillTileWithNetworkImage:self.imgurImages[positionHash%self.imgurImages.count]];
}

- (void)infiniteScrollView:(INFScrollView *)infiniteScrollView isDoneUsingTile:(INFScrollViewTile *)tile atPositionHash:(NSInteger)positionHash
{
    [(INFNetworkImageScrollViewTile *)tile fillTileWithNetworkImage:nil];
}

- (INFScrollViewTile *)infiniteScrollViewTileForInfiniteScrollView:(INFScrollView *)infiniteScrollView
{
    return [[INFNetworkImageScrollViewTile alloc] init];
}

@end
