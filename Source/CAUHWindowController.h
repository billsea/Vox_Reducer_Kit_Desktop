/*	Copyright: 	© Copyright 2005 Apple Computer, Inc. All rights reserved.

	Disclaimer:	IMPORTANT:  This Apple software is supplied to you by Apple Computer, Inc.
			("Apple") in consideration of your agreement to the following terms, and your
			use, installation, modification or redistribution of this Apple software
			constitutes acceptance of these terms.  If you do not agree with these terms,
			please do not use, install, modify or redistribute this Apple software.

			In consideration of your agreement to abide by the following terms, and subject
			to these terms, Apple grants you a personal, non-exclusive license, under Apple’s
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
#include <AudioToolbox/AudioToolbox.h>
#include <AudioUnit/AudioUnit.h>

#import <Cocoa/Cocoa.h>
#import "AudioFileReceiver_Protocol.h"


@class AudioFileListView;
class CAComponent;

@interface HostingWindowController : NSWindowController <AudioFileReceiver>
{
    // IB: AU Selection
    IBOutlet NSMatrix *				uiAUTypeMatrix;
    IBOutlet NSButton *				uiAudioFileButton;
    IBOutlet NSPopUpButton *		uiAUPopUpButton;
    IBOutlet NSBox *				uiAUViewContainer;
    
    // IB: Audio Transport
    IBOutlet NSButton *				uiPlayStopButton;
    IBOutlet AudioFileListView *	uiAudioFileTableView;
    IBOutlet NSTextField *			uiAudioFileNowPlayingName;
	IBOutlet NSButton *				uiPauseButton;
    IBOutlet NSComboBox *			uiPresetList;
	
    // Post-nib view manufacturing
    NSScrollView *					mScrollView;
    
	//Display
	IBOutlet NSTextField *			audioCounter;
	NSTimer *						framesDisplayTimer;
	
	
    // AU Tracking
    OSType							mComponentHostType;
	CAComponent *					mAUList;
   NSMutableArray *				mAudioFileList;
    // AudioFile / AUGraph members
    AudioFilePlayID					mAFPID;
	AUGraph							mGraph;
	AUNode							mTargetNode, mOutputNode;
	AudioUnit						mTargetUnit, mOutputUnit;
	
	//devices
	AudioDeviceID 					mDevice;
	
	//presets
	CFPropertyListRef			mClassData;
	//ComponentDescription	*	mCurrentTargetDesc;
	
	NSMutableArray *factoryPresetsArray;
	IBOutlet NSWindow * newPresetCustomSheet;
	IBOutlet NSWindow * addSongCustomSheet;
	IBOutlet NSButton *				uiPresetSaveButton;
	IBOutlet NSButton *				uiPresetCloseButton;
	IBOutlet NSTextField *			uiPresetNameText;
	
	
	
	
	
	//slider
	IBOutlet NSView *				uiParam1SliderKnob;
	
	
	//Playlist
	IBOutlet NSButton *				uiAddButton;
	IBOutlet NSButton *				uiClearButton;
	IBOutlet NSButton *				uiSaveButton;
	IBOutlet NSButton *				uiMoveDownButton;
	IBOutlet NSButton *				uiMoveUpButton;
	IBOutlet NSBrowser *			uiAddSongBrowser;
	IBOutlet NSButton *				uiAddSongOpenButton;
	IBOutlet NSButton *				uiAddSongCancelButton;
}
bool 		SetTargetUnit (ComponentDescription& 	inDesc,
						   const CFPropertyListRef 	inClassData = NULL);
- (void) displayCounter:(NSTimer *)aTimer;
- (void) saveDataToDisk;
- (void)loadDataFromDisk;
- (void)savePreset:(NSString *)newPresetName;
-(void)restorePreset: (int)listIndex;
- (void) loadFactoryPresetNumber:(NSNumber *)presetNumber :(NSString *)presetName;
- (void) loadUserPresetNumber:(NSNumber *)presetNumber :(NSString *)presetName;

#pragma mark IB Actions
- (IBAction)iaAUTypeChanged:(id)sender;
- (IBAction)iaAUPopUpButtonPressed:(id)sender;
- (IBAction)iaPlayStopButtonPressed:(id)sender;
- (IBAction)iaStopButtonPressed:(id)sender;
- (IBAction)iaPauseButtonPressed:(id)sender;
- (IBAction)iaSetMasterVolume:(id)sender;
- (IBAction) appHelpLink:(id)sender;
- (IBAction)iaClearButtonPressed:(id)sender;
- (IBAction)iaSaveButtonPressed:(id)sender;
- (IBAction)iaMoveDownButtonPressed:(id)sender;
- (IBAction)iaMoveUpButtonPressed:(id)sender;
- (IBAction)iaPresetChanged:(id)sender;
- (IBAction)iaSavePreset:(id)sender;
- (IBAction)iaCancelClosePreset:(id)sender;
- (IBAction)iaAddButtonPressed:(id)sender;
- (IBAction)iaAddOpenButtonPressed:(id)sender;
- (IBAction)iaAddCancelButtonPressed:(id)sender;
@end


