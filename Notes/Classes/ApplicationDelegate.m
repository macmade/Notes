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
#import "MainWindowController.h"

@interface ApplicationDelegate()

@property( atomic, readonly          ) NSURL                        * applicationDocumentsDirectory;
@property( atomic, readwrite, strong ) NSManagedObjectModel         * managedObjectModelInstance;
@property( atomic, readwrite, strong ) NSManagedObjectContext       * managedObjectContextInstance;
@property( atomic, readwrite, strong ) NSPersistentStoreCoordinator * persistentStoreCoordinatorInstance;
@property( atomic, readwrite, strong ) MainWindowController         * mainWindowController;

- ( IBAction )saveAction: ( id )sender;

@end

@implementation ApplicationDelegate

- ( void )applicationDidFinishLaunching: ( NSNotification * )notification
{
    self.mainWindowController = [ MainWindowController new ];
    
    [ self.mainWindowController.window center ];
    [ self.mainWindowController showWindow: nil ];
}

- ( void )applicationWillTerminate: ( NSNotification * )notification
{
    ( void )notification;
}

#pragma mark - Core Data stack

@synthesize persistentStoreCoordinator  = _persistentStoreCoordinator;
@synthesize managedObjectModel          = _managedObjectModel;
@synthesize managedObjectContext        = _managedObjectContext;

- ( NSURL * )applicationDocumentsDirectory
{
    NSURL * url;
    
    @synchronized( self )
    {
        url = [ [ [ NSFileManager defaultManager ] URLsForDirectory: NSApplicationSupportDirectory inDomains: NSUserDomainMask ] lastObject ];
        
        return [ url URLByAppendingPathComponent: [ [ NSBundle mainBundle ] bundleIdentifier ] ];
    }
}

- ( NSManagedObjectModel * )managedObjectModel
{
    NSURL * url;
    
    @synchronized( self )
    {
        if ( self.managedObjectModelInstance == nil )
        {
            url                             = [ [ NSBundle mainBundle ] URLForResource: @"Notes" withExtension: @"momd" ];
            self.managedObjectModelInstance = [ [ NSManagedObjectModel alloc ] initWithContentsOfURL: url ];
        }
        
        return self.managedObjectModelInstance;
    }
}

- ( NSManagedObjectContext * )managedObjectContext
{
    @synchronized( self )
    {
        if( self.managedObjectModelInstance == nil )
        {
            if( self.persistentStoreCoordinator == nil )
            {
                return nil;
            }
            
            self.managedObjectContextInstance                            = [ [ NSManagedObjectContext alloc ] initWithConcurrencyType: NSMainQueueConcurrencyType ];
            self.managedObjectContextInstance.persistentStoreCoordinator = self.persistentStoreCoordinator;
        }
        
        return _managedObjectContext;
    }
}

- ( NSPersistentStoreCoordinator * )persistentStoreCoordinator
{
    NSError             * error;
    NSMutableDictionary * errorInfo;
    NSString            * errorMessage;
    BOOL                  failure;
    
    @synchronized( self )
    {
        if( self.persistentStoreCoordinatorInstance == nil )
        {
            {
                NSDictionary * properties;
                
                errorMessage = @"There was an error creating or loading the application's saved data.";
                properties   = [ self.applicationDocumentsDirectory resourceValuesForKeys: @[ NSURLIsDirectoryKey ] error: &error ];
                
                if( properties )
                {
                    if( [ properties[ NSURLIsDirectoryKey ] boolValue ] == NO )
                    {
                        errorMessage = [ NSString stringWithFormat: @"Expected a folder to store application data, found a file (%@).", self.applicationDocumentsDirectory.path ];
                        failure      = YES;
                    }
                }
                else if( error.code == NSFileReadNoSuchFileError )
                {
                    error = nil;
                    
                    [ [ NSFileManager defaultManager ] createDirectoryAtURL: self.applicationDocumentsDirectory withIntermediateDirectories: YES attributes: nil error: &error ];
                }
            }
            
            if( failure == NO && error == nil )
            {
                {
                    NSURL * url;
                    
                    self.persistentStoreCoordinatorInstance = [ [ NSPersistentStoreCoordinator alloc ] initWithManagedObjectModel: self.managedObjectModel ];
                    url                                     = [ self.applicationDocumentsDirectory URLByAppendingPathComponent: @"OSXCoreDataObjC.storedata" ];
                    
                    if( [ self.persistentStoreCoordinatorInstance addPersistentStoreWithType: NSXMLStoreType configuration: nil URL: url options: nil error: &error ] == NO )
                    {
                        self.persistentStoreCoordinatorInstance = nil;
                    }
                }
            }
            
            if( failure || error )
            {
                errorInfo                                    = [ NSMutableDictionary dictionary ];
                errorInfo[ NSLocalizedDescriptionKey]        = @"Failed to initialize the application's saved data.";
                errorInfo[ NSLocalizedFailureReasonErrorKey] = errorMessage;
                
                if( error )
                {
                    errorInfo[ NSUnderlyingErrorKey ] = error;
                }
                
                [ NSApp presentError: [ NSError errorWithDomain: [ [ NSBundle mainBundle ] bundleIdentifier ] code: 9999 userInfo: errorInfo ] ];
            }
        }
        
        return self.persistentStoreCoordinatorInstance;
    }
}

#pragma mark - Core Data Saving and Undo support

- ( IBAction )saveAction: ( id )sender
{
    NSError * error;
    
    if( [ self.managedObjectContext commitEditing ] == NO )
    {
        NSLog( @"%@:%@ - Unable to commit editing before saving", self.class, NSStringFromSelector( _cmd ) );
    }
    
    if( self.managedObjectContext.hasChanges && [ self.managedObjectContext save: &error ] )
    {
        [ [ NSApplication sharedApplication ] presentError: error ];
    }
}

- ( NSUndoManager * )windowWillReturnUndoManager: ( NSWindow * )window
{
    return self.managedObjectContext.undoManager;
}

- ( NSApplicationTerminateReply )applicationShouldTerminate: ( NSApplication * )sender
{
    NSError * error;
    NSAlert * alert;
    
    if( self.managedObjectContext == nil )
    {
        return NSTerminateNow;
    }
    
    if( [ self.managedObjectContext commitEditing ] == NO )
    {
        NSLog( @"%@:%@ - Unable to commit editing to terminate", self.class, NSStringFromSelector( _cmd ) );
        
        return NSTerminateCancel;
    }
    
    if( self.managedObjectContext.hasChanges == NO )
    {
        return NSTerminateNow;
    }
    
    if( [ self.managedObjectContext save: &error ] == NO )
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
