/*
     File: AVScreenShackDocument.m
 Abstract: Document, owns session, screen capture input, and movie file output
  Version: 1.0
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2011 Apple Inc. All Rights Reserved.
 
 */

#import "AVScreenShackDocument.h"

#import <AVFoundation/AVFoundation.h>

@implementation AVScreenShackDocument

@synthesize captureSession = captureSession, captureScreenInput = captureScreenInput;

#pragma mark Capture

- (BOOL)createCaptureSession:(NSError **)outError
{
    /* Create a capture session. */
    captureSession = [[AVCaptureSession alloc] init];
	if ([captureSession canSetSessionPreset:AVCaptureSessionPresetHigh])
    {
        /* Specifies capture settings suitable for high quality video and audio output. */
		[captureSession setSessionPreset:AVCaptureSessionPresetHigh];
    }
    
    /* Add the main display as a capture input. */
    display = CGMainDisplayID();
    captureScreenInput = [[AVCaptureScreenInput alloc] initWithDisplayID:display];
    if ([captureSession canAddInput:captureScreenInput]) 
    {
        [captureSession addInput:captureScreenInput];
    } 
    else 
    {
        return NO;
    }
    
    /* Add a movie file output + delegate. */
    captureMovieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
    [captureMovieFileOutput setDelegate:self];
    if ([captureSession canAddOutput:captureMovieFileOutput]) 
    {
        [captureSession addOutput:captureMovieFileOutput];
    } 
    else 
    {
        return NO;
    }
    
    return YES;
}

/*
 AVCaptureVideoPreviewLayer is a subclass of CALayer that you use to display 
 video as it is being captured by an input device.
 
 You use this preview layer in conjunction with an AV capture session.
 */
-(void)addCaptureVideoPreview
{
    /* Create a video preview layer. */
	AVCaptureVideoPreviewLayer *videoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:captureSession];
    
    /* Configure it.*/
	[videoPreviewLayer setFrame:[[captureView layer] bounds]];
	[videoPreviewLayer setAutoresizingMask:kCALayerWidthSizable|kCALayerHeightSizable];
    
    /* Add the preview layer as a sublayer to the view. */
    [[captureView layer] addSublayer:videoPreviewLayer];
    /* Specify the background color of the layer. */
	[[captureView layer] setBackgroundColor:CGColorGetConstantColor(kCGColorBlack)];
    [videoPreviewLayer release];    
}

/*
 An AVCaptureScreenInput's minFrameDuration is the reciprocal of its maximum frame rate.  This property
 may be used to request a maximum frame rate at which the input produces video frames.  The requested
 rate may not be achievable due to overall bandwidth, so actual frame rates may be lower.
 */
- (float)maximumScreenInputFramerate
{
	Float64 minimumVideoFrameInterval = CMTimeGetSeconds([captureScreenInput minFrameDuration]);
	return minimumVideoFrameInterval > 0.0f ? 1.0f/minimumVideoFrameInterval : 0.0;
}

/* Set the screen input maximum frame rate. */
- (void)setMaximumScreenInputFramerate:(float)maximumFramerate
{
	CMTime minimumFrameDuration = CMTimeMake(1, (int32_t)maximumFramerate);
    /* Set the screen input's minimum frame duration. */
	[captureScreenInput setMinFrameDuration:minimumFrameDuration];
}

/* Add a display as an input to the capture session. */
-(void)addDisplayInputToCaptureSession:(CGDirectDisplayID)newDisplay cropRect:(CGRect)cropRect
{
    /* Indicates the start of a set of configuration changes to be made atomically. */
    [captureSession beginConfiguration];
    
    /* Is this display the current capture input? */
    if ( newDisplay != display ) 
    {
        /* Display is not the current input, so remove it. */
        [captureSession removeInput:captureScreenInput];
        AVCaptureScreenInput *newScreenInput = [[AVCaptureScreenInput alloc] initWithDisplayID:newDisplay];
        
        [captureScreenInput release];
        captureScreenInput = newScreenInput;
        if ( [captureSession canAddInput:captureScreenInput] )
        {
            /* Add the new display capture input. */
            [captureSession addInput:captureScreenInput];
        }
        [self setMaximumScreenInputFramerate:[self maximumScreenInputFramerate]];
    }
    /* Set the bounding rectangle of the screen area to be captured, in pixels. */
    [captureScreenInput setCropRect:cropRect];
    
    /* Commits the configuration changes. */
    [captureSession commitConfiguration];
}


/* Informs the delegate when all pending data has been written to the output file. */
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error
{
    if (error) 
    {
        [self presentError:error];
		return;
    }
    
    [[NSWorkspace sharedWorkspace] openURL:outputFileURL];
}

#pragma mark NSDocument

/* Initializes a AVScreenShackDocument document. */
- (id)initWithType:(NSString *)typeName error:(NSError **)outError
{
    self = [super initWithType:typeName error:outError];
    
    if (self) 
    {        
        BOOL success = [self createCaptureSession:outError];
        if (!success) 
        {
            [self release];
            return nil;
        }
    }
    
    return self;
}

- (void)dealloc
{
    [captureSession release];
    [captureScreenInput release];
    [captureMovieFileOutput release];
    
    [super dealloc];
}

- (NSString *)windowNibName
{
	/* 
       Override returning the nib file name of the document.
     
	   If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, 
       you should remove this method and override -makeWindowControllers instead.
     */
    
	return @"AVScreenShackDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
    [super windowControllerDidLoadNib:aController];
	
    [self addCaptureVideoPreview];

    /* Start the capture session running. */
    [captureSession startRunning];

	[[aController window] setContentBorderThickness:75.f forEdge:NSMinYEdge];
	[[aController window] setMovableByWindowBackground:YES];
}

/* Called when the document is closed. */
- (void)close
{
    /* Stop the capture session running. */
    [captureSession stopRunning];
    
    [super close];
}

/* AVScreenShackDocument does not support saving. */
-(BOOL)isDocumentEdited
{
    return NO;
}

#pragma mark Crop Rect

#define kShadyWindowLevel   (NSDockWindowLevel + 1000)

/* Draws a crop rect on the display. */
- (void)drawMouseBoxView:(DrawMouseBoxView*)view didSelectRect:(NSRect)rect
{
	/* Map point into global coordinates. */
    NSRect globalRect = rect;
    NSRect windowRect = [[view window] frame];
    globalRect = NSOffsetRect(globalRect, windowRect.origin.x, windowRect.origin.y);
	globalRect.origin.y = CGDisplayPixelsHigh(CGMainDisplayID()) - globalRect.origin.y;
	CGDirectDisplayID displayID = display;
	uint32_t matchingDisplayCount = 0;
    /* Get a list of online displays with bounds that include the specified point. */
	CGError e = CGGetDisplaysWithPoint(NSPointToCGPoint(globalRect.origin), 1, &displayID, &matchingDisplayCount);
	if ((e == kCGErrorSuccess) && (1 == matchingDisplayCount)) 
    {
        /* Add the display as a capture input. */
        [self addDisplayInputToCaptureSession:displayID cropRect:rect];
    }
    
	for (NSWindow* w in [NSApp windows])
	{
		if ([w level] == kShadyWindowLevel)
			[w close];
	}
	[[NSCursor currentCursor] pop];
}

/* 
 Called when the user sets a Crop Rect for the display.
 
 First dims the display, then allows the user specify a rectangular
 area of the display to capture.
*/
- (IBAction)setDisplayAndCropRect:(id)sender
{
	for (NSScreen* screen in [NSScreen screens]) 
    {
		NSRect frame = [screen frame];
		NSWindow * window = [[NSWindow alloc] initWithContentRect:frame styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
		[window setBackgroundColor:[NSColor blackColor]];
		[window setAlphaValue:.5];
		[window setLevel:kShadyWindowLevel];
		[window setReleasedWhenClosed:YES];
		DrawMouseBoxView* drawMouseBoxView = [[DrawMouseBoxView alloc] initWithFrame:frame];
		drawMouseBoxView.delegate = self;
		[window setContentView:drawMouseBoxView];
		[drawMouseBoxView release];
		[window makeKeyAndOrderFront:self];
	}
	
	[[NSCursor crosshairCursor] push];
}

#pragma mark Start/Stop Button Actions

/* Called when the user presses the 'Start' button to start a recording. */
- (IBAction)startRecording:(id)sender
{
	NSLog(@"Minimum Frame Duration: %f, Crop Rect: %@, Scale Factor: %f, Capture Mouse Clicks: %@", CMTimeGetSeconds([captureScreenInput minFrameDuration]), NSStringFromRect(NSRectFromCGRect([captureScreenInput cropRect])), [captureScreenInput scaleFactor], [captureScreenInput capturesMouseClicks] ? @"Yes" : @"No");
	
	char *tempNameBytes = tempnam([[@"~/Desktop/" stringByStandardizingPath] fileSystemRepresentation], "AVScreenShack_");
	NSString *tempName = [[[NSString alloc] initWithBytesNoCopy:tempNameBytes length:strlen(tempNameBytes) encoding:NSUTF8StringEncoding freeWhenDone:YES] autorelease];
	
    /* Starts recording to a given URL. */
    [captureMovieFileOutput startRecordingToOutputFileURL:[NSURL fileURLWithPath:[tempName stringByAppendingPathExtension:@"mov"]] recordingDelegate:self];
}

/* Called when the user presses the 'Stop' button to stop a recording. */
- (IBAction)stopRecording:(id)sender
{
    [captureMovieFileOutput stopRecording];
}

@end
