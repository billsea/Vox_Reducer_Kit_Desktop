/*	Copyright: 	¬¨¬© Copyright 2005 Apple Computer, Inc. All rights reserved.

	Disclaimer:	IMPORTANT:  This Apple software is supplied to you by Apple Computer, Inc.
			("Apple") in consideration of your agreement to the following terms, and your
			use, installation, modification or redistribution of this Apple software
			constitutes acceptance of these terms.  If you do not agree with these terms,
			please do not use, install, modify or redistribute this Apple software.

			In consideration of your agreement to abide by the following terms, and subject
			to these terms, Apple grants you a personal, non-exclusive license, under Apple‚Äö√Ñ√¥s
			copyrights in this original Apple software (the "Apple Software"), to use,
			reproduce, modify and redistribute the Apple Software, with or without
			modifications, in source and/or binary forms; provided that if you redistribute
			the Apple Software in its entirety and without modifications, you must retain
			this notice and the following text and disclaimers in all such redistributions of
			the Apple Software.  Neither the name, trademarks, service marks or logos of
			Apple Computer, Inc. may be used to endorse or promote products derived from the
			Apple Software without specific prior written permission from Apple.  Except as
			expressly stated in this notice, no other rights or licenses, express or implied,
			are granted by Apple herein, including but not limited to any patent rights that
			may be infringed by your derivative works or by other works in which the Apple
			Software may be incorporated.

			The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO
			WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED
			WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A PARTICULAR
			PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND OPERATION ALONE OR IN
			COMBINATION WITH YOUR PRODUCTS.

			IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR
			CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
			GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
			ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION
			OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER UNDER THEORY OF CONTRACT, TORT
			(INCLUDING NEGLIGENCE), STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN
			ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/
#include "CAAudioTimeStamp.h"
#include "CAAudioHardwareDevice.h"
#include "CAAudioHardwareSystem.h"
//////// original /////////
#import <CoreAudioKit/CoreAudioKit.h>
#import <AudioUnit/AUCocoaUIView.h>

#include "CAComponent.h"
#include "CAComponentDescription.h"
#include "AudioFilePlay.h"

#import "CAUHWindowController.h"

#import "AudioFileListView.h"
///////////////////////////

UInt32 timeValOffset;

void AudioFileNotificationHandler (void *inRefCon, OSStatus inStatus)
{
    HostingWindowController *SELF = (HostingWindowController *)inRefCon;
    [SELF performSelectorOnMainThread:@selector(iaPlayStopButtonPressed:) withObject:SELF waitUntilDone:NO];
}

int componentCountForAUType(OSType inAUType)
{
	CAComponentDescription desc = CAComponentDescription(inAUType);
	return desc.Count();
}

void getComponentsForAUType(OSType inAUType, CAComponent *ioCompBuffer, int count)
{
	CAComponentDescription desc = CAComponentDescription(inAUType);
	CAComponent *last = NULL;
	
	for (int i = 0; i < count; ++i) {
		ioCompBuffer[i] = CAComponent(desc, last);
		last = &(ioCompBuffer[i]);
	}
}

@implementation HostingWindowController
+ (BOOL)plugInClassIsValid:(Class) pluginClass
{
	if ([pluginClass conformsToProtocol:@protocol(AUCocoaUIBase)]) {
		if ([pluginClass instancesRespondToSelector:@selector(interfaceVersion)] &&
			[pluginClass instancesRespondToSelector:@selector(uiViewForAudioUnit:withSize:)]) {
			return YES;
		}
	}
	
    return NO;
}

- (void)showCocoaViewForAU:(AudioUnit)inAU
{
	// get AU's Cocoa view property
    UInt32 						dataSize;
    Boolean 					isWritable;
    AudioUnitCocoaViewInfo *	cocoaViewInfo = NULL;
    UInt32						numberOfClasses;
    
    OSStatus result = AudioUnitGetPropertyInfo(	inAU,
                                                kAudioUnitProperty_CocoaUI,
                                                kAudioUnitScope_Global, 
                                                0,
                                                &dataSize,
                                                &isWritable );
    
    numberOfClasses = (dataSize - sizeof(CFURLRef)) / sizeof(CFStringRef);
    
    NSURL 	 *	CocoaViewBundlePath = nil;
    NSString *	factoryClassName = nil;
    
	// Does view have custom Cocoa UI?
    if ((result == noErr) && (numberOfClasses > 0) ) {
        cocoaViewInfo = (AudioUnitCocoaViewInfo *)malloc(dataSize);
        if(AudioUnitGetProperty(		inAU,
                                        kAudioUnitProperty_CocoaUI,
                                        kAudioUnitScope_Global,
                                        0,
                                        cocoaViewInfo,
                                        &dataSize) == noErr) {
            CocoaViewBundlePath	= (NSURL *)cocoaViewInfo->mCocoaAUViewBundleLocation;
			
			// we only take the first view in this example.
            factoryClassName	= (NSString *)cocoaViewInfo->mCocoaAUViewClass[0];
        } else {
            if (cocoaViewInfo != NULL) {
				free (cocoaViewInfo);
				cocoaViewInfo = NULL;
			}
        }
    }
	
	NSView *AUView = nil;
	BOOL wasAbleToLoadCustomView = NO;
	
	// [A] Show custom UI if view has it
	if (CocoaViewBundlePath && factoryClassName) {
		NSBundle *viewBundle  	= [NSBundle bundleWithPath:[CocoaViewBundlePath path]];
		if (viewBundle == nil) {
			NSLog (@"Error loading AU view's bundle");
		} else {
			Class factoryClass = [viewBundle classNamed:factoryClassName];
			NSAssert (factoryClass != nil, @"Error getting AU view's factory class from bundle");
			
			// make sure 'factoryClass' implements the AUCocoaUIBase protocol
			NSAssert(	[HostingWindowController plugInClassIsValid:factoryClass],
						@"AU view's factory class does not properly implement the AUCocoaUIBase protocol");
			
			// make a factory
			id factoryInstance = [[[factoryClass alloc] init] autorelease];
			NSAssert (factoryInstance != nil, @"Could not create an instance of the AU view factory");
			// make a view
			AUView = [factoryInstance	uiViewForAudioUnit:inAU
										withSize:[[mScrollView contentView] bounds].size];
			
			// cleanup
			[CocoaViewBundlePath release];
			if (cocoaViewInfo) {
				UInt32 i;
				for (i = 0; i < numberOfClasses; i++)
					CFRelease(cocoaViewInfo->mCocoaAUViewClass[i]);
				
				free (cocoaViewInfo);
			}
			wasAbleToLoadCustomView = YES;
		}
	}
	
	if (!wasAbleToLoadCustomView) {
		// [B] Otherwise show generic Cocoa view
		AUView = [[AUGenericView alloc] initWithAudioUnit:inAU];
		[(AUGenericView *)AUView setShowsExpertParameters:YES];
    }
	
	// Display view
	NSRect viewFrame = [AUView frame];
	
	
	
	NSSize frameSize = [NSScrollView	frameSizeForContentSize:viewFrame.size
										  hasHorizontalScroller: false//  [mScrollView hasHorizontalScroller]
											hasVerticalScroller:false
													 borderType:[mScrollView borderType] ];
	
	
	NSRect newFrame;
	newFrame.origin = [mScrollView frame].origin;
	newFrame.size = frameSize;
	
	NSRect currentFrame = [mScrollView frame];
	[mScrollView setFrame:newFrame];
	[mScrollView setDocumentView:AUView];
	
	[mScrollView setAutohidesScrollers:true]; 
	
	NSSize oldContentSize = [[[self window] contentView] frame].size;
	NSSize newContentSize = oldContentSize;
	newContentSize.width += (newFrame.size.width - currentFrame.size.width);
	newContentSize.height += (newFrame.size.height - currentFrame.size.height);
	
	[[self window] setContentSize:newContentSize];
}

- (void)synchronizePlayStopButton
{
    if (mComponentHostType == kAudioUnitType_Effect) {
        [uiPlayStopButton setEnabled:[mAudioFileList count] > 0];
		[uiPauseButton setEnabled:[mAudioFileList count] > 0];
    } else {
        [uiPlayStopButton setEnabled:YES];
		[uiPauseButton setEnabled:YES];
    }
}

- (void)synchronizeForNewAUType
{
    // [A] what is new AUType?
    int selectedRow = 1; //[uiAUTypeMatrix selectedRow];
    mComponentHostType = (selectedRow == 0) ? kAudioUnitType_Generator : kAudioUnitType_Effect;
    int index;
	
    // [B] sync with new AUType
    //   [1] get new AUList
	if (mAUList != NULL) {
		free (mAUList);
		mAUList = NULL;
	}
	
	int componentCount = componentCountForAUType(mComponentHostType);
	UInt32 dataByteSize = componentCount * sizeof(CAComponent);
	mAUList = static_cast<CAComponent *>(malloc(dataByteSize));
	memset (mAUList, 0, dataByteSize);
	getComponentsForAUType(mComponentHostType, mAUList, componentCount);
	
	//   [2] populate AUPopUp with new list
    [uiAUPopUpButton removeAllItems];
	
	for (int i = 0; i < componentCount; ++i) {
		NSString * auName  = (NSString *)(mAUList[i].GetAUName());
		if ([auName isEqual: @"voxReducer II"]){
			//[uiAUPopUpButton addItemWithTitle:(NSString *)(mAUList[i].GetAUName())];
			index=i;
			
		}
		
	}
	
	
	
    
    //   [3] enable AudioFileDrawerToggle button for effects
    if (mComponentHostType == kAudioUnitType_Effect) {
        [uiAudioFileButton setEnabled:YES];
    } else {
        [uiAudioFileButton setEnabled:NO];
        [(NSDrawer *)[[[self window] drawers] objectAtIndex:0] close];
    }
    
    //   [4] other UI
    [self synchronizePlayStopButton];
    
    //   [5] select top-of-list AU & show its UI
	
	// replace effect AU in chain
	
	ComponentDescription desc = mAUList[index].Desc();//[[mAUList objectAtIndex:index] componentDescription];
		
		if (mTargetNode) {
			// remove the old view first before closing the AU
			[[mScrollView documentView] removeFromSuperview];
			verify_noerr (AUGraphRemoveNode(mGraph, mTargetNode));
		}
		
		verify_noerr (AUGraphNewNode(mGraph, &desc, 0, NULL, &mTargetNode));
		verify_noerr (AUGraphGetNodeInfo(mGraph, mTargetNode, NULL, NULL, NULL, &mTargetUnit));
		verify_noerr (AUGraphUpdate (mGraph, NULL));
		
		[self showCocoaViewForAU:mTargetUnit];
	
	
	[self loadPresets];
	[self loadStoredPresets];
	
   // [self iaAUPopUpButtonPressed:self];  
}

- (void) loadPresets
{
	NSArray		*factoryPresets		= nil;
	UInt32		dataSize			= sizeof(factoryPresets);
	
	ComponentResult err = AudioUnitGetProperty(mTargetUnit, 
											   kAudioUnitProperty_FactoryPresets,
											   kAudioUnitScope_Global, 
											   0, 
											   &factoryPresets, 
											   &dataSize);

	factoryPresetsArray = [[NSMutableArray alloc] init];
	
	if(noErr == err) {
		unsigned i;
		for(i = 0; i < [factoryPresets count]; ++i) {
			AUPreset *preset = (AUPreset *)[factoryPresets objectAtIndex:i];
			NSNumber *presetNumber = [NSNumber numberWithInt:preset->presetNumber];
			NSString *presetName = [(NSString *)preset->presetName copy];
			
			[factoryPresetsArray addObject:[NSDictionary dictionaryWithObjectsAndKeys:presetNumber, @"presetNumber", presetName, @"presetName", [NSNull null], @"presetPath", nil]];
			
			[presetName release];

		}
		
	}
	
	//no need to do this twice
	//[uiPresetList addItemsWithObjectValues:[factoryPresetsArray valueAtIndex:0 inPropertyWithKey:@"presetName"]];
	
	[factoryPresets release];
}

- (void) loadStoredPresets
{
	//open and read preset file
	NSString *folder = @"~/Library/Audio/Presets/loudsoftware.com/voxReducer II"; //source folder
	folder = [folder stringByExpandingTildeInPath];

	NSString *auPresetsPath = folder;
	
	NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:auPresetsPath];
	NSString *path = nil;
	//NSMutableArray *result = [[NSMutableArray alloc] init];
	
	while((path = [enumerator nextObject])) {
		// Skip files that aren't AU presets
		if(NO == [[path pathExtension] isEqualToString:@"aupreset"])
			continue;
		
		NSNumber *presetNumber = [NSNumber numberWithInt:-1];
		NSString *presetName = [[path lastPathComponent] stringByDeletingPathExtension];
		NSString *presetPath = [auPresetsPath stringByAppendingPathComponent:path];
		
		//[result addObject:[NSDictionary dictionaryWithObjectsAndKeys:presetNumber, @"presetNumber", presetName, @"presetName", presetPath, @"presetPath", nil]];
		
		//add to preset array 
		[factoryPresetsArray addObject:[NSDictionary dictionaryWithObjectsAndKeys:presetNumber, @"presetNumber", presetName, @"presetName", [NSNull null], @"presetPath", nil]];
		
	}
	
	//add array to preset dropdown
	[uiPresetList addItemsWithObjectValues:[factoryPresetsArray valueAtIndex:0 inPropertyWithKey:@"presetName"]];
	
	
}


- (void)promptForPresetSave
{
	//prompt for preset name
	[NSApp beginSheet:newPresetCustomSheet 
	   modalForWindow:[self window] 
		modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];

}

- (void)sheetDidEnd:(NSWindow *)sheet
		 returnCode:(int)returnCode
		contextInfo:(void *)contextInfo
{

	NSLog(@"sheet ended: code = %d", returnCode);
}



- (void)savePreset:(NSString *)newPresetName
{
		if (mClassData) CFRelease (mClassData);
		mClassData = NULL;

		AUPreset myPreset;
		myPreset.presetNumber = -1; //should be less than zero as this is a "user preset" name we're setting
		myPreset.presetName = (CFStringRef)newPresetName;

	 
		OSErr err =  AudioUnitSetProperty (mTargetUnit, 
											kAudioUnitProperty_PresentPreset, kAudioUnitScope_Global, 0,
											&myPreset, sizeof(myPreset));
	
		// get property
		UInt32 size = sizeof(CFPropertyListRef);
		err = AudioUnitGetProperty (mTargetUnit, 
											kAudioUnitProperty_ClassInfo, kAudioUnitScope_Global, 0,
											&mClassData, &size);
	// print to console
	//CFShow (mClassData);
	
	//save to file
	id classInfoPlist = NULL;
	UInt32 dataSize = sizeof(classInfoPlist);
	
	err = AudioUnitGetProperty(mTargetUnit,
							   kAudioUnitProperty_ClassInfo, 
							   kAudioUnitScope_Global, 
							   0, 
							   &classInfoPlist, 
							   &dataSize);
	if(noErr != err)
		return;

	NSString *error = nil;
	NSData *xmlData = [NSPropertyListSerialization dataFromPropertyList:classInfoPlist format:NSPropertyListXMLFormat_v1_0 errorDescription:&error];
	if(nil == xmlData) {
		NSLog(error);
		[error release];
		return;
	}
	 
	//write file
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *folder = @"~/Library/Audio/Presets/loudsoftware.com/voxReducer II"; //destination folder
	folder = [folder stringByExpandingTildeInPath];
	
	if ([fileManager fileExistsAtPath: folder] == NO)
	{
		[fileManager createDirectoryAtPath: folder attributes: nil];
	}
	
	NSString *fileName;
	fileName = [NSString stringWithFormat:@"%@.aupreset", newPresetName];
	
	//NSString *fileName = @"newTest.aupreset"; //new file name
	NSString *path = [folder stringByAppendingPathComponent: fileName];
	[xmlData writeToURL:[NSURL fileURLWithPath:path] atomically:YES];
 
	
	//Add to preset array & combo box list
	AUPreset *preset = &myPreset;
	NSNumber *presetNumber = [NSNumber numberWithInt:preset->presetNumber];
	NSString *presetName = [(NSString *)preset->presetName copy];
	
	[factoryPresetsArray addObject:[NSDictionary dictionaryWithObjectsAndKeys:presetNumber, @"presetNumber", presetName, @"presetName", [NSNull null], @"presetPath", nil]];
	
	//add new preset to combo box
	NSArray * sarray = [[NSArray alloc] initWithArray:factoryPresetsArray];
	NSArray * nameArray = [[NSArray alloc] initWithArray:[sarray valueAtIndex:0 inPropertyWithKey:@"presetName" ]];
	[uiPresetList addItemWithObjectValue: [nameArray objectAtIndex:[nameArray count] - 1]];
	
	[presetName release];

}


	
- (void)addLinkToFiles:(NSArray *)inFiles
{
    [mAudioFileList addObjectsFromArray:inFiles];
    [self synchronizePlayStopButton];
    [uiAudioFileTableView reloadData];
}

- (void)createGraph
{
	verify_noerr (NewAUGraph(&mGraph));
	
	CAComponentDescription desc = CAComponentDescription (	kAudioUnitType_Output,
															kAudioUnitSubType_DefaultOutput,
															kAudioUnitManufacturer_Apple	);
    
	verify_noerr (AUGraphNewNode(mGraph, &desc, 0, NULL, &mOutputNode));
	verify_noerr (AUGraphOpen(mGraph));
    verify_noerr (AUGraphGetNodeInfo(mGraph, mOutputNode, NULL, NULL, NULL, &mOutputUnit));
	
	
}

- (void)startGraph
{
	
    verify_noerr (AUGraphConnectNodeInput (mGraph, mTargetNode, 0, mOutputNode, 0));
    verify_noerr (AUGraphUpdate (mGraph, NULL) == noErr);
    verify_noerr (AUGraphInitialize(mGraph) == noErr);
	verify_noerr (AUGraphStart(mGraph) == noErr);
	
	timeValOffset = AudioConvertHostTimeToNanos( AudioGetCurrentHostTime() ) / 1000;
	
	
	/* setup a timer to display counter value*/
    framesDisplayTimer = [[NSTimer scheduledTimerWithTimeInterval:0.01		// interval, 0.1 seconds
														   target:self
														 selector:@selector(displayCounter:)		// call this method
														 userInfo:nil
														  repeats:YES] retain];					// repeat until we cancel it
	
}

- (void)stopGraph
{
	[framesDisplayTimer invalidate];
	
	verify_noerr (AUGraphStop(mGraph));
	verify_noerr (AUGraphUninitialize(mGraph));
	verify_noerr (AUGraphDisconnectNodeInput (mGraph, mOutputNode, 0));
	verify_noerr (AUGraphUpdate (mGraph, NULL));
	if (mAFPID) {
		verify_noerr (AFP_Disconnect(mAFPID));
		verify_noerr (DisposeAudioFilePlayID(mAFPID));
		[uiAudioFileNowPlayingName setStringValue:@""];
		mAFPID = NULL;
	}
}

- (void)pauseGraph
{
	/*
	verify_noerr (AUGraphStop(mGraph));
	verify_noerr (AUGraphUninitialize(mGraph));
	verify_noerr (AUGraphDisconnectNodeInput (mGraph, mOutputNode, 0));
	verify_noerr (AUGraphUpdate (mGraph, NULL));
	if (mAFPID) {
		verify_noerr (AFP_Disconnect(mAFPID));
		verify_noerr (DisposeAudioFilePlayID(mAFPID));
		[uiAudioFileNowPlayingName setStringValue:@""];
		mAFPID = NULL;
	}
	 */
}

- (void)destroyGraph
{
	// stop graph if necessary
    Boolean isRunning = FALSE;
	verify_noerr (AUGraphIsRunning(mGraph, &isRunning));
	if (isRunning)
		[self stopGraph];
	
	// close and destroy
	verify_noerr (AUGraphClose(mGraph));
	verify_noerr (DisposeAUGraph(mGraph));
}

- (void)loadAudioFile:(NSString *)inAudioFileName
{
	FSRef destFSRef;
	UInt8 *pathName = (UInt8 *)[inAudioFileName cString];
	verify_noerr (FSPathMakeRef(pathName, &destFSRef, NULL));
	
	verify_noerr (NewAudioFilePlayID(&destFSRef, &mAFPID));
	verify_noerr (AFP_SetNotifier(mAFPID, AudioFileNotificationHandler, self));
	
	verify_noerr (AFP_SetDestination(mAFPID, mTargetUnit, 0));
	verify_noerr (AFP_Connect(mAFPID));
	
	

}


- (id)init
{
	
	
	self = [super init];
    if (self) {
		
		//mAudioFileList = [[NSMutableArray alloc] init];
		
		//Load data from files
		//[self loadDataFromDisk];
		
		
    }
	return self;
}



- (void)awakeFromNib
{
	
	//	get the device we're attached to
	mDevice = CAAudioHardwareSystem::GetDefaultDevice(kAudioDeviceSectionOutput, false);
	
	
	//CAAudioHardwareDevice theDevice(mDevice);
	
   mAudioFileList = [[NSMutableArray alloc] init];
   //Load data from files
	[self loadDataFromDisk];
	
    // create scroll-view
    NSRect frameRect = [[uiAUViewContainer contentView] frame];
    mScrollView = [[[NSScrollView alloc] initWithFrame:frameRect] autorelease];
    [mScrollView setDrawsBackground:NO];
    [mScrollView setHasHorizontalScroller:YES];
    [mScrollView setHasVerticalScroller:YES];
    [uiAUViewContainer setContentView:mScrollView];
    
    // dispatched setup
    [self createGraph];
    [self synchronizeForNewAUType];
    
	// make this the app. delegate
    [NSApp setDelegate:self.owner];

    // set initial volume level to halfway
    OSErr status;
    status = AudioUnitSetParameter(mOutputUnit, kHALOutputParam_Volume,
                                   kAudioUnitScope_Global, 0, 0.5, 0);
    [audioCounter setIntValue:5];
	
	
	
}

- (void) displayCounter:(NSTimer *)aTimer
{
	
	//	make a device object
	CAAudioHardwareDevice theDevice(mDevice);
	
	//	get the current time (in samples)
	AudioTimeStamp theCurrentTime = CAAudioTimeStamp::kZero;
	AudioTimeStamp timeTrans = CAAudioTimeStamp::kZero;
	theCurrentTime.mFlags =  kAudioTimeStampHostTimeValid;
	theDevice.GetCurrentTime(theCurrentTime);
	
	
	//set this constant(look for correct one) then translate
	//theDevice.TranslateTime(theCurrentTime,timeTrans);
	
	//Float64 fq =  AudioGetHostClockFrequency(); 

	@try
	{
			
	//SMPTETime  smpte;
	//smpte = theCurrentTime.mSMPTETime;
		
	//works
	//UInt32 timeVal  = AudioConvertHostTimeToNanos( AudioGetCurrentHostTime() ) / 1000;
	UInt32 timeVal  = AudioConvertHostTimeToNanos( theCurrentTime.mHostTime ) / 1000;

	//convert to readable time. *** host time continues even when audio is stopped ***
	timeVal = abs(abs(timeVal) - abs(timeValOffset));
	
	//[audioCounter setIntValue: timeVal];
	
	//NSLog(@"host time = %D", timeVal);
	
	
	
	}@catch (NSException *exception) {
		NSLog(@"main: Caught %@: %@", [exception name], [exception reason]);
	}
	
}

-(void)dealloc
{
	
	[framesDisplayTimer invalidate];
	[framesDisplayTimer release];
	
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
	if (mAUList != NULL) {
		free(mAUList);
		mAUList = NULL;
	}
	
    [mAudioFileList release];
    [factoryPresetsArray release];
	
    if (mAFPID)
		verify_noerr(DisposeAudioFilePlayID(mAFPID));
    
    [self destroyGraph];
	
	[super dealloc];
}

- (IBAction)iaSavePreset:(id)sender
{
	if([[uiPresetNameText stringValue] isEqualToString:@""])
	{
		int serNum = NSRunAlertPanel(@"Unable to save preset", @"Please enter a preset name",
									 nil, nil,nil,nil);
	}
	else
	{
		[self savePreset:[uiPresetNameText stringValue]];
		[uiPresetNameText setStringValue:@""];
		//hide sheet
		[newPresetCustomSheet orderOut:sender];
		
		//return to normal event handling
		[NSApp endSheet:newPresetCustomSheet returnCode:1];
	}
	
	
}

- (IBAction)iaCancelClosePreset:(id)sender
{
	//hide sheet
	[newPresetCustomSheet orderOut:sender];
	
	//return to normal event handling
	[NSApp endSheet:newPresetCustomSheet returnCode:1];
}




- (IBAction)iaAUTypeChanged:(id)sender
{
    [self synchronizeForNewAUType];
}

- (IBAction)iaAUPopUpButtonPressed:(id)sender
{
	
	
	
    // replace effect AU in chain
	int index =[uiAUPopUpButton indexOfSelectedItem];
	ComponentDescription desc = mAUList[index].Desc();//[[mAUList objectAtIndex:index] componentDescription];
	
	if (mTargetNode) {
			// remove the old view first before closing the AU
		[[mScrollView documentView] removeFromSuperview];
		verify_noerr (AUGraphRemoveNode(mGraph, mTargetNode));
    }
	
    verify_noerr (AUGraphNewNode(mGraph, &desc, 0, NULL, &mTargetNode));
	verify_noerr (AUGraphGetNodeInfo(mGraph, mTargetNode, NULL, NULL, NULL, &mTargetUnit));
    verify_noerr (AUGraphUpdate (mGraph, NULL));
    
	[self showCocoaViewForAU:mTargetUnit];
}

- (IBAction)iaStopButtonPressed:(id)sender
{
	[self stopGraph];
	
	[uiPauseButton setState:0];
	[uiPauseButton setEnabled:FALSE];
}

- (IBAction)iaAddButtonPressed:(id)sender
{
	
	//prompt for song name
	NSArray *fileTypes = [NSArray arrayWithObjects:@"m4a",@"wav", nil];
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];

	[oPanel setCanChooseDirectories:NO];
    [oPanel setCanChooseFiles:YES];
    [oPanel setAllowsMultipleSelection:YES];
    [oPanel setTitle:@"Select Audio Files"];
    [oPanel setPrompt:@"Select"];
	[oPanel setDirectory:@"~/Music"];
	
    int result = [oPanel runModalForTypes:fileTypes];
    
    if (result == NSOKButton) {
        NSArray *fileToOpen = [oPanel filenames];
		[self addLinkToFiles:fileToOpen]; 
	}
	
}

- (IBAction)iaAddOpenButtonPressed:(id)sender
{
	
	//hide sheet
	[addSongCustomSheet orderOut:sender];
	
	//return to normal event handling
	[NSApp endSheet:addSongCustomSheet returnCode:1];
	
}
- (IBAction)iaAddCancelButtonPressed:(id)sender
{
	//hide sheet
	[addSongCustomSheet orderOut:sender];
	
	//return to normal event handling
	[NSApp endSheet:addSongCustomSheet returnCode:1];
	
}

//set current audio frame
- (void)currentAudioFrame:(AudioTimeStamp *)timeStamp
{
	
	UInt32 size = sizeof(AudioTimeStamp);
	AudioUnitGetProperty (mOutputUnit, kAudioUnitProperty_CurrentPlayTime, kAudioUnitScope_Global, 0, timeStamp, &size);
}


//sets playback position using timestamp
- (void)setPlayHeadPosition: (AudioTimeStamp *)timeStamp
{
	
	//if (timeStamp)
	//{
	timeStamp->mFlags = kAudioTimeStampSampleTimeValid;
	AudioUnitSetProperty (mOutputUnit, kAudioUnitProperty_ScheduleStartTimeStamp, kAudioUnitScope_Global, 0, timeStamp, sizeof(AudioTimeStamp));
	//}
	}

		
- (IBAction)iaPauseButtonPressed:(id)sender
{
	
	if (!mAFPID) {
		return;	
	}
	
NSButton * pauseButton = sender;

if ([pauseButton state]==0)
{
	
		
	AUGraphStart(mGraph);
	
	/* setup a timer to display counter value*/
    framesDisplayTimer = [[NSTimer scheduledTimerWithTimeInterval:0.01		// interval, 0.1 seconds
														   target:self
														 selector:@selector(displayCounter:)		// call this method
														 userInfo:nil
														  repeats:YES] retain];					// repeat until we cancel it
	
	
}else{
	//[self currentAudioFrame:_playPauseTimeStamp];
	AUGraphStop(mGraph);

	[framesDisplayTimer invalidate];
}
	

	
	
}

- (IBAction)iaPlayStopButtonPressed:(id)sender
{


	
    if (sender == self) {
        // change button icon manually if this function is called internally
        [uiPlayStopButton setState:([uiPlayStopButton state] == NSOffState) ? NSOnState : NSOffState];
    }
    
    Boolean isRunning = FALSE;
	verify_noerr (AUGraphIsRunning(mGraph, &isRunning));
	
	// [1] if the AUGraph is running, stop it
    if (isRunning) {
        // stop graph, update UI & return
		[self stopGraph];
		
		//[uiAUTypeMatrix setEnabled:YES];
       // [uiAUPopUpButton setEnabled:YES];
        return;
    }
    
	// [2] otherwise start the AUGraph
    // load file
    if (mComponentHostType == kAudioUnitType_Effect) {
		int selectedRow = [uiAudioFileTableView selectedRow];
		if ( (selectedRow < 0) || ([mAudioFileList count] == 0) ) return;	// no file selected
		
		NSString *audioFileName = (NSString *)[mAudioFileList objectAtIndex:selectedRow];
		[self loadAudioFile:audioFileName];
		
        // set filename in UI
        [uiAudioFileNowPlayingName setStringValue:[audioFileName lastPathComponent]];
    }
	
    [uiAUTypeMatrix setEnabled:NO];
    [uiAUPopUpButton setEnabled:NO];
	
	[uiPauseButton setState:0];
	[uiPauseButton setEnabled:true];
	[self startGraph];
}


- (IBAction)iaClearButtonPressed:(id)sender;
{

	[mAudioFileList removeObjectAtIndex:[uiAudioFileTableView selectedRow]];
	[uiAudioFileTableView reloadData];
}

- (IBAction)iaSaveButtonPressed:(id)sender;
{
	[self saveDataToDisk];
}

- (IBAction)iaMoveUpButtonPressed:(id)sender
{
	//move selection towards the top of list
	int selRow = [uiAudioFileTableView selectedRow];

	@try
	{
	
	if(selRow != 0)
	{
		 NSRange range = NSMakeRange(selRow-1, 2);
		NSIndexSet * indexes = [[NSIndexSet alloc] initWithIndexesInRange:range];
		NSMutableArray * lArr = [[NSMutableArray alloc] initWithArray: [mAudioFileList objectsAtIndexes:indexes]];
		[mAudioFileList replaceObjectAtIndex:selRow withObject:[lArr objectAtIndex:0]];
		[mAudioFileList replaceObjectAtIndex:selRow-1 withObject:[lArr objectAtIndex:1] ];
		
		
	    [uiAudioFileTableView selectRow:selRow-1 byExtendingSelection:false];
		[uiAudioFileTableView reloadData];
	
		
	}
		
	
	}@catch (NSException *exception) {
		NSLog(@"main: Caught %@: %@", [exception name], [exception reason]);
	}	
	
}

- (IBAction)iaMoveDownButtonPressed:(id)sender
{
	//move selection towards the bottom of list
	int selRow = [uiAudioFileTableView selectedRow];
	
	@try
	{
		
		if(selRow < [mAudioFileList count]-1)
		{
			NSRange range = NSMakeRange(selRow, 2);
			NSIndexSet * indexes = [[NSIndexSet alloc] initWithIndexesInRange:range];
			NSMutableArray * lArr = [[NSMutableArray alloc] initWithArray: [mAudioFileList objectsAtIndexes:indexes]];
			[mAudioFileList replaceObjectAtIndex:selRow withObject:[lArr objectAtIndex:1]];
			[mAudioFileList replaceObjectAtIndex:selRow+1 withObject:[lArr objectAtIndex:0] ];
			
			[uiAudioFileTableView selectRow:selRow+1 byExtendingSelection:false];
			[uiAudioFileTableView reloadData];
		}
		
		
	}@catch (NSException *exception) {
		NSLog(@"main: Caught %@: %@", [exception name], [exception reason]);
	}	
	
}


- (IBAction)iaPresetChanged:(id)sender
{
	
	NSComboBox * psBox = [sender self];
	
	if ( [psBox indexOfSelectedItem] > 0 )
	{
		[self restorePreset: [psBox indexOfSelectedItem]];
	}
	else
	{
		[self promptForPresetSave];
	}
}

-(void)restorePreset: (int)listIndex
{
	NSArray * sarray = [[NSArray alloc] initWithArray:factoryPresetsArray];
	NSArray * nameArray = [[NSArray alloc] initWithArray:[sarray valueAtIndex:0 inPropertyWithKey:@"presetName" ]];
	NSArray * numberArray = [[NSArray alloc] initWithArray:[sarray valueAtIndex:0 inPropertyWithKey:@"presetNumber" ]];
	
	//handle user presets differently (user presets have a negative integer value)
	if((int)[[numberArray objectAtIndex:listIndex - 1] intValue] >= 0)
	{
		[self loadFactoryPresetNumber:[numberArray objectAtIndex:listIndex - 1]:[nameArray objectAtIndex:listIndex - 1]];
	}
	else
	{
		[self loadUserPresetNumber:[numberArray objectAtIndex:listIndex - 1]:[nameArray objectAtIndex:listIndex - 1]];
	}
}




- (void) loadUserPresetNumber:(NSNumber *)presetNumber :(NSString *)presetName
{
	//open and read preset file
	NSFileManager *fileManager = [NSFileManager defaultManager];
    
	NSString *folder = @"~/Library/Audio/Presets/loudsoftware.com/voxReducer II"; //source folder
	folder = [folder stringByExpandingTildeInPath];
	
	if ([fileManager fileExistsAtPath: folder] == NO)
	{
		[fileManager createDirectoryAtPath: folder attributes: nil];
	}
	
	NSString *fileName;
	fileName = [NSString stringWithFormat:@"%@.aupreset", presetName];
	
	//NSString *fileName = @"newTest.aupreset"; //new file name
	NSString *path = [folder stringByAppendingPathComponent: fileName];
	NSURL *presetURL = [NSURL fileURLWithPath:path];
	NSError *error = nil;
	NSData *xmlData = [NSData dataWithContentsOfURL:presetURL
											options:NSUncachedRead error:&error];
	
	if(nil == xmlData)
		return;
	
	NSString *errorString = nil;
	NSPropertyListFormat plistFormat = NSPropertyListXMLFormat_v1_0;
	id classInfoPlist = [NSPropertyListSerialization propertyListFromData:xmlData 
														 mutabilityOption:NSPropertyListImmutable 
																   format:&plistFormat 
														 errorDescription:&errorString];
	
	
	//set audio unit preset
	ComponentResult err = AudioUnitSetProperty(mTargetUnit,
											   kAudioUnitProperty_ClassInfo, 
											   kAudioUnitScope_Global, 
											   0, 
											   &classInfoPlist, 
											   sizeof(classInfoPlist));
		
		//notify any listeners of this change:
		AudioUnitParameter changedUnit;
		changedUnit.mAudioUnit = mTargetUnit;
		changedUnit.mParameterID = kAUParameterListener_AnyParameter;
		err = AUParameterListenerNotify (NULL, NULL, &changedUnit);
		
}


- (void) loadFactoryPresetNumber:(NSNumber *)presetNumber :(NSString *)presetName
{
	NSParameterAssert(nil != presetNumber);
	NSParameterAssert(0 <= [presetNumber intValue]);
	
	AUPreset preset;
	preset.presetNumber = (SInt32)[presetNumber intValue];
	preset.presetName = (CFStringRef)presetName;
	
	ComponentResult err = AudioUnitSetProperty(mTargetUnit, 
											   kAudioUnitProperty_PresentPreset,
											   kAudioUnitScope_Global, 
											   0, 
											   &preset, 
											   sizeof(preset));
	if(noErr != err)
		NSLog(@"Error setting preset");
	
		AudioUnitParameter changedUnit;
		changedUnit.mAudioUnit = mTargetUnit;
		changedUnit.mParameterID = kAUParameterListener_AnyParameter;
		err = (AUParameterListenerNotify (NULL, NULL, &changedUnit));
	
}




- (int)numberOfRowsInTableView:(NSTableView *)inTableView
{
    int count = [mAudioFileList count];
    return (count > 0) ? count : 1;
}

- (id)tableView:(NSTableView *)inTableView objectValueForTableColumn:(NSTableColumn *)inTableColumn row:(int)inRow
{
    int count = [mAudioFileList count];
    return (count > 0) ?	[(NSString *)[mAudioFileList objectAtIndex:inRow] lastPathComponent] :
                            @"-- Add your music files here --";
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)inSender
{
	return YES;
}

- (IBAction)iaSetMasterVolume:(id)sender
{
	OSErr status;	
	int mVal = [sender intValue];
	float volume =(float)mVal/10;

	status = AudioUnitSetParameter(mOutputUnit, kHALOutputParam_Volume, kAudioUnitScope_Global, 0, volume, 0 );
	[audioCounter setIntValue: volume * 10];
}

- (IBAction) appHelpLink:(id)sender
{
	NSString *stringURL = @"http://loudsoftware.com/helpSection/?HG=voxReducer%20Kit%20II";	
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:stringURL]];
}


// Save
- (void) saveDataToDisk
{
	NSMutableDictionary * rootObject;
	rootObject = [NSMutableDictionary dictionary];
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
    
	NSString *folder = @"~/Library/Application Support/voxReducerKit2"; //destination folder
	folder = [folder stringByExpandingTildeInPath];
	
	if ([fileManager fileExistsAtPath: folder] == NO)
	{
		[fileManager createDirectoryAtPath: folder attributes: nil];
	}

	NSString *fileName = @"playList.plist"; //new file name
	
	NSString *path = [folder stringByAppendingPathComponent: fileName];
	[rootObject setValue: mAudioFileList forKey:@"playList"];

	[NSKeyedArchiver archiveRootObject: rootObject toFile: path];

	NSLog(@"Playlist saved");
}

- (void) loadDataFromDisk
{


	NSFileManager *fileManager = [NSFileManager defaultManager];
    
	NSString *folder = @"~/Library/Application Support/voxReducerKit2"; //source folder
	folder = [folder stringByExpandingTildeInPath];
	
	if ([fileManager fileExistsAtPath: folder] == NO)
	{
		[fileManager createDirectoryAtPath: folder attributes: nil];
	}
	
	NSString *fileName = @"playList.plist"; //new file name
	NSString *path = [folder stringByAppendingPathComponent: fileName];
	
	NSDictionary *rootObject;
	rootObject = [NSKeyedUnarchiver unarchiveObjectWithFile:path];    

	[mAudioFileList autorelease];
	mAudioFileList = [[NSMutableArray alloc] initWithArray: [rootObject valueForKey:@"playList"]];
    [uiAudioFileTableView reloadData];
	
	NSLog(@"filecount: %d",[mAudioFileList count] );

		
}


@end
