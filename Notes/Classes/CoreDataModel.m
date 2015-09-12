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

#import "CoreDataModel.h"

@interface CoreDataModel()

@property( atomic, readwrite, strong ) NSManagedObjectModel         * model;
@property( atomic, readwrite, strong ) NSPersistentStoreCoordinator * store;
@property( atomic, readwrite, strong ) NSManagedObjectContext       * context;
@property( atomic, readwrite, strong ) NSString                     * name;
@property( atomic, readwrite, strong ) NSString                     * type;
@property( atomic, readonly          ) NSURL                        * documentsDirectory;

- ( BOOL )createModel;
- ( BOOL )createStore;
- ( BOOL )createContext;

@end

@implementation CoreDataModel

- ( nullable instancetype )init
{
    return [ self initWithModelName: @"" storeType: @"" ];
}

- ( nullable instancetype )initWithModelName: ( NSString * )name storeType: ( NSString * )type
{
    if( ( self = [ super init ] ) )
    {
        self.name = name;
        self.type = type;
        
        if( [ self createModel ] == NO )
        {
            return nil;
        }
        
        if( [ self createStore ] == NO )
        {
            return nil;
        }
        
        if( [ self createContext ] == NO )
        {
            return nil;
        }
    }
    
    return self;
}

- ( BOOL )createModel
{
    NSURL                * url;
    NSManagedObjectModel * model;
    
    if ( self.model != nil )
    {
        return NO;
    }
    
    url   = [ [ NSBundle mainBundle ] URLForResource: self.name withExtension: @"momd" ];
    model = [ [ NSManagedObjectModel alloc ] initWithContentsOfURL: url ];
    
    if( model == nil )
    {
        return NO;
    }
    
    self.model = model;
    
    return YES;
}

- ( BOOL )createStore
{
    NSString            * identifier;
    NSError             * error;
    NSMutableDictionary * errorInfo;
    NSString            * errorMessage;
    BOOL                  failure;
    
    @synchronized( self )
    {
        if( self.store != nil )
        {
            return NO;
        }
        
        identifier = [ [ NSBundle mainBundle ] bundleIdentifier ];
        
        {
            NSDictionary * properties;
            
            errorMessage = @"There was an error creating or loading the application's saved data.";
            properties   = [ self.documentsDirectory resourceValuesForKeys: @[ NSURLIsDirectoryKey ] error: &error ];
            
            if( properties )
            {
                if( [ properties[ NSURLIsDirectoryKey ] boolValue ] == NO )
                {
                    errorMessage = [ NSString stringWithFormat: @"Expected a folder to store application data, found a file (%@).", self.documentsDirectory.path ];
                    failure      = YES;
                }
            }
            else if( error.code == NSFileReadNoSuchFileError )
            {
                error = nil;
                
                [ [ NSFileManager defaultManager ] createDirectoryAtURL: self.documentsDirectory withIntermediateDirectories: YES attributes: nil error: &error ];
            }
        }
            
        if( failure == NO && error == nil )
        {
            {
                NSURL                        * url;
                NSPersistentStoreCoordinator * store;
                NSString                     * ext;
                
                if( self.type == NSSQLiteStoreType )
                {
                    ext = @".sqlite";
                }
                else if( self.type == NSXMLStoreType )
                {
                    ext = @".storedata";
                }
                
                store = [ [ NSPersistentStoreCoordinator alloc ] initWithManagedObjectModel: self.model ];
                url   = [ self.documentsDirectory URLByAppendingPathComponent: [ NSString stringWithFormat: @"%@%@", self.name, ext ] ];
                
                if( [ store addPersistentStoreWithType: self.type configuration: nil URL: url options: nil error: &error ] )
                {
                    self.store = store;
                }
                else
                {
                    failure = YES;
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
            
            [ NSApp presentError: [ NSError errorWithDomain: identifier code: 9999 userInfo: errorInfo ] ];
            
            return NO;
        }
    }
        
    return YES;
}

- ( BOOL )createContext
{
    NSManagedObjectContext * context;
    
    if ( self.context != nil )
    {
        return NO;
    }
    
    if( self.store == nil )
    {
        return NO;
    }
    
    context                            = [ [ NSManagedObjectContext alloc ] initWithConcurrencyType: NSMainQueueConcurrencyType ];
    context.persistentStoreCoordinator = self.store;
            
    if( context == nil )
    {
        return NO;
    }
    
    self.context = context;
    
    return YES;
}

- ( NSURL * )documentsDirectory
{
    NSURL    * url;
    NSString * identifier;
    
    @synchronized( self )
    {
        url        = [ [ [ NSFileManager defaultManager ] URLsForDirectory: NSApplicationSupportDirectory inDomains: NSUserDomainMask ] lastObject ];
        identifier = [ [ NSBundle mainBundle ] bundleIdentifier ];
        
        return [ url URLByAppendingPathComponent: identifier ];
    }
}

@end
