/*******************************************************************************
 * The MIT License (MIT)
 * 
 * Copyright (c) 2015 Jean-David Gadina - www-xs-labs.com
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 ******************************************************************************/

#import "ApplicationDelegate.h"
#import "CoreDataModel.h"
#import "MainWindowController.h"

@interface ApplicationDelegate()

@property( atomic, readwrite, strong ) CoreDataModel        * data;
@property( atomic, readwrite, strong ) MainWindowController * mainWindowController;

- ( IBAction )saveDocument: ( id )sender;

@end

@implementation ApplicationDelegate

- ( void )applicationDidFinishLaunching: ( NSNotification * )notification
{
    CoreDataModel * data;
    
    ( void )notification;
    
    data = [ [ CoreDataModel alloc ] initWithModelName: @"Notes" storeType: NSSQLiteStoreType ];
    
    if( data != nil )
    {
        self.data                 = data;
        self.mainWindowController = [ MainWindowController new ];
        
        [ self.mainWindowController.window center ];
        [ self.mainWindowController showWindow: nil ];
    }
}

- ( void )applicationWillTerminate: ( NSNotification * )notification
{
    ( void )notification;
}

- ( BOOL )applicationShouldTerminateAfterLastWindowClosed: ( NSApplication * )sender
{
    ( void )sender;
    
    return YES;
}

#pragma mark - Core Data Saving and Undo support

- ( IBAction )saveDocument: ( id )sender
{
    NSError * error;
    
    ( void )sender;
    
    if( [ self.data.context commitEditing ] == NO )
    {
        NSLog( @"%@:%@ - Unable to commit editing before saving", self.class, NSStringFromSelector( _cmd ) );
    }
    
    if( self.data.context.hasChanges && [ self.data.context save: &error ] == NO )
    {
        [ [ NSApplication sharedApplication ] presentError: error ];
    }
}

- ( NSUndoManager * )windowWillReturnUndoManager: ( NSWindow * )window
{
    ( void )window;
    
    return self.data.context.undoManager;
}

- ( NSApplicationTerminateReply )applicationShouldTerminate: ( NSApplication * )sender
{
    NSError * error;
    NSAlert * alert;
    
    if( self.data.context == nil )
    {
        return NSTerminateNow;
    }
    
    if( [ self.data.context commitEditing ] == NO )
    {
        NSLog( @"%@:%@ - Unable to commit editing to terminate", self.class, NSStringFromSelector( _cmd ) );
        
        return NSTerminateCancel;
    }
    
    if( self.data.context.hasChanges == NO )
    {
        return NSTerminateNow;
    }
    
    if( [ self.data.context save: &error ] == NO )
    {     
        if( [ sender presentError: error ] )
        {
            return NSTerminateCancel;
        }
        
        alert = [ NSAlert new ];
        
        [ alert addButtonWithTitle: NSLocalizedString( @"Quit anyway", @"" ) ];
        [ alert addButtonWithTitle: NSLocalizedString( @"Cancel", @"" ) ];
        
        alert.messageText     = NSLocalizedString( @"Could not save changes while quitting. Quit anyway?", @"" );
        alert.informativeText = NSLocalizedString( @"Quitting now will lose any changes you have made since the last successful save", @"" );
        
        if( [ alert runModal ] == NSAlertFirstButtonReturn )
        {
            return NSTerminateCancel;
        }
    }
    
    return NSTerminateNow;
}

@end
