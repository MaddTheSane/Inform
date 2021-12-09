//
//  IFExtensionsManager.m
//  Inform
//
//  Created by Andrew Hunter on 06/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//  Rewritten by Toby Nelson in 2014.
//

#import "IFExtensionsManager.h"
#import "IFMaintenanceTask.h"
#import "IFUtility.h"
#import "NSString+IFStringExtensions.h"
#import "IFCompilerSettings.h"
#import "IFJSProject.h"
#import "IFProjectController.h"

NSString* IFExtensionsUpdatedNotification   = @"IFExtensionsUpdatedNotification";
NSString* IFCensusFinishedNotification      = @"IFCensusFinishedNotification";
NSString* IFCensusFinishedButDontUpdateExtensionsWebPageNotification = @"IFCensusFinishedButDontUpdateExtensionsWebPageNotification";

static int maxErrorMessagesToDisplay = 3;

// *******************************************************************************************
@implementation IFExtensionInfo

-(instancetype) initWithDisplayName: (NSString*) displayName
                 filepath: (NSString*) filepath
                   author: (NSString*) author
                  version: (NSString*) version
                  md5Hash: (NSString*) md5Hash
                isBuiltIn: (BOOL) isBuiltIn {
	self = [super init];
    
	if (self) {
        self.displayName = displayName;
        self.filepath    = filepath;
        self.author      = author;
        self.version     = version;
        self.md5Hash     = md5Hash;
        self.isBuiltIn   = isBuiltIn;
    }
    return self;
}

-(NSComparisonResult) caseInsensitiveCompare:(IFExtensionInfo *) b {
    NSComparisonResult result = [self.displayName localizedCaseInsensitiveCompare: b.displayName];
    if( result != NSOrderedSame ) {
        return result;
    }
    result = [self.author localizedCaseInsensitiveCompare: b.author];
    if( result != NSOrderedSame ) {
        return result;
    }

    result = [self.filepath compare: b.filepath];
    if( result != NSOrderedSame ) {
        return result;
    }

    return NSOrderedSame;
}


+(NSString*) canonicalTitle: (NSString*) displayName {
    // Remove any initial "The " from the name.
    NSString* result = displayName;
    if( [[result lowercaseString] startsWith: @"the "] ) {
        result = [result substringFromIndex:4];
    }
    
    // Remove proviso in brackets
    if ( [result endsWith:@")"] ) {
        // The name of the extension may be followed by a proviso in brackets: remove it
        NSUInteger location = [result rangeOfString:@" ("].location;
        if(( location != NSNotFound ) && (location > 1)) {
            result = [result substringToIndex: location];
        }
    }
    return result;
}

-(NSString*) safeVersion {
    if( self.version == nil ) {
        return @"Version 1";
    }
    return self.version;
}

-(BOOL) stringEqual:(NSString*) string1 to:(NSString*) string2 {
    if(( string1 == nil ) || (string2 == nil ))
    {
        return (string1 == string2);
    }

    return [string1 isEqual: string2];
}


- (BOOL)isEqual:(id)other {
    if (other == self)
        return YES;
    if (!other || ![other isKindOfClass:[self class]])
        return NO;
    IFExtensionInfo * another = other;

    if( ![self stringEqual: self.displayName to: another.displayName] )
        return NO;
    if( ![self stringEqual: self.filepath to: another.filepath] )
        return NO;
    if( ![self stringEqual: self.author to: another.author] )
        return NO;
    if( ![self stringEqual: self.version to: another.version] )
        return NO;
    if( ![self stringEqual: self.md5Hash to: another.md5Hash] )
        return NO;
    if( self.isBuiltIn != another.isBuiltIn )
        return NO;
    return YES;
}
@end

// *******************************************************************************************
@implementation IFExtensionDownload

-(instancetype) initWithURL: (NSURL*) url
           window: (NSWindow*) aWindow
   notifyDelegate: (NSObject*) notifyDelegate
     javascriptId: (NSString*) javascriptId {
	self = [super init];

	if (self) {
        self.url            = url;
        self.state          = IFExtensionDownloadNotStarted;
        self.window         = aWindow;
        self.receivedData   = [NSMutableData data];
        self.notifyDelegate = notifyDelegate;
        self.javascriptId   = javascriptId;
        self.expectedLength = NSURLResponseUnknownLength;
    }

    return self;
}


-(NSString*) safeVersion {
    if (self.version == nil) {
        return @"Version 1";
    }
    return self.version;
}

// = Download and Install =
- (BOOL) startDownloadAndInstall {
    // Create the request
    NSURLRequest *theRequest = [NSURLRequest requestWithURL: self.url
                                                cachePolicy: NSURLRequestUseProtocolCachePolicy
                                            timeoutInterval: 10.0];

    // Create the connection with the request and start loading the data
    self.connection = [[NSURLConnection alloc] initWithRequest: theRequest
                                                       delegate: self];
    if (self.connection == nil) {
        self.receivedData = [NSMutableData data];
        return NO;
    }
    self.state          = IFExtensionDownloadInProgress;
    self.expectedLength = NSURLResponseUnknownLength;

    return YES;
}

- (void)connection: (NSURLConnection *)connection
didReceiveResponse: (NSURLResponse *)response
{
    if (connection == self.connection)
    {
        if ( [response isKindOfClass: [NSHTTPURLResponse class]] )
        {
            NSUInteger statusCode = [((NSHTTPURLResponse *)response) statusCode];
            if (statusCode >= 400)
            {
                NSString* localizedStringForStatusCode = [NSHTTPURLResponse localizedStringForStatusCode: statusCode];
                [connection cancel];  // stop connecting; no more delegate messages
                NSDictionary *errorInfo = @{NSLocalizedDescriptionKey: [NSString stringWithFormat:
                                                      [IFUtility localizedString:@"Server returned status code %d, local string %@"],
                                                      statusCode, localizedStringForStatusCode]};
                NSError *statusError = [NSError errorWithDomain: @"Error"
                                                           code: statusCode
                                                       userInfo: errorInfo];
                [self   connection: connection
                  didFailWithError: statusError];
                return;
            }
        }

        // This method is called when the server has determined that it
        // has enough information to create the NSURLResponse object.
        
        // It can be called multiple times, for example in the case of a
        // redirect, so each time we reset the data.
        
        [self.receivedData setLength:0];
        
        self.expectedLength = [response expectedContentLength];
    }
}

- (void)connection: (NSURLConnection *)connection
    didReceiveData: (NSData *)data
{
    if (connection == self.connection)
    {
        // do something with the data object.
        [self.receivedData appendData:data];
    }
}

- (void)connection: (NSURLConnection *)connection
  didFailWithError: (NSError *)error
{
    if (connection == self.connection)
    {
        //NSString* file = [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey];

        // Log message
        NSString* message = [NSString stringWithFormat:[IFUtility localizedString: @"Failed to Download Extension Explanation - %@"],
                             [error localizedDescription]];
        
        [[IFExtensionsManager sharedNaturalInformExtensionsManager] addError: message];
        
        self.state        = IFExtensionDownloadFailed;
        self.connection   = nil;
        self.receivedData = nil;
        
        [[IFExtensionsManager sharedNaturalInformExtensionsManager] downloadAndInstallFinished: self];
    }
}

- (void)connectionDidFinishLoading: (NSURLConnection *)connection
{
    if (connection == self.connection)
    {
        IFExtensionsManager* mgr = [IFExtensionsManager sharedNaturalInformExtensionsManager];
        //NSLog(@"Download succeeded! Received %d bytes of data", [self.receivedData length]);
        
        // Get temporary filename
        char tempFilename[256];
        sprintf(tempFilename, "%stemp.XXXXXX", [NSTemporaryDirectory() cStringUsingEncoding:NSUTF8StringEncoding]);
        int result = mkstemp(tempFilename);
        if( result != -1 ) {
            NSString* filename = [[NSString alloc] initWithCString: tempFilename
                                                           encoding: NSUTF8StringEncoding];
            
            // Save the data to a temporary file
            if( [self.receivedData writeToFile: filename
                                    atomically: YES] ) {
                // Install this extension
                NSString* finalPath = nil;
                NSString* title     = nil;
                NSString* author    = nil;
                NSString* version   = nil;
                if ( [mgr installExtension: filename
                                 finalPath: &finalPath
                                     title: &title
                                    author: &author
                                   version: &version
                        showWarningPrompts: NO
                                    notify: NO]) {
                    self.title = title;
                    self.author = author;
                    self.version = version;
                    self.state = IFExtensionDownloadAndInstallSucceeded;
                }
                else {
                    self.state = IFExtensionInstallFailed;

                    // Log error
                    [mgr addError: [IFUtility localizedString: @"Failed to Install Extension Explanation"]];
                }

                // Remove temporary file
                NSError* error;
                [[NSFileManager defaultManager] removeItemAtPath: filename
                                                           error: &error];
            }
            else {
                self.state = IFExtensionInstallFailed;
                // Log error
                NSString* message = [NSString stringWithFormat: [IFUtility localizedString: @"Failed to Install Extension Explanation - Could not write to file '%@'"], filename];
                [mgr addError: message];
            }
        }
        else {
            self.state = IFExtensionInstallFailed;
            [mgr addError: [IFUtility localizedString: @"Failed to Install Extension Explanation - Could not make temporary filename"]];
        }

        self.connection     = nil;
        self.receivedData   = nil;

        [mgr downloadAndInstallFinished: self];
    }
}

@end

// *******************************************************************************************
@implementation IFExtensionsManager {
    // Collection directories to look
    NSMutableArray* extensionCollectionDirectories;		// Standard set of extension directories

    // Cache data
    NSDictionary* cacheExtensionDictionary;				// Caches the extension dictionary until we next clear the cache
    NSArray*      cacheAvailableExtensions;             // Caches the available extensions array until we next clear the cache
    int           userLibraryCount;                     // Number of extension dictionaries that are 'installed' to ~/Library/Inform rather than internal to the Inform app bundle resources (i.e. one)

    // Update extensions
    BOOL          updatingExtensions;					// Set to YES if an update is pending

    BOOL _rebuildAvailableExtensionsCache;
    BOOL _rebuildExtensionDictionaryCache;
    BOOL _cacheChanged;

    // Download and install
    NSMutableArray* downloads;                          // Mutable array of current downloads
    int numberOfBatchedExtensions;                      // How many things we are downloading and installing
    int numberOfErrors;                                 // Number of failed download / installs
    NSMutableString* errorString;                       // Multiple error messages are accumulated into this string
    IFProgress* dlProgress;                             // Progress
}

// = Shared extension manager =

+ (IFExtensionsManager*) sharedNaturalInformExtensionsManager {
	static IFExtensionsManager* mgr = nil;

	if (!mgr) {
		mgr = [[IFExtensionsManager alloc] init];
	}

	return mgr;
}

// = Initialisation =

- (instancetype) init {
	self = [super init];

	if (self) {
		extensionCollectionDirectories  = [[NSMutableArray alloc] init];

		cacheAvailableExtensions = nil;
        cacheExtensionDictionary = nil;

		// Get the list of directories where extensions might live

        userLibraryCount = 1;
        [self addExtensionCollectionDirectory: [IFUtility pathForInformExternalExtensions]];        // External directory of extensions
        [self addExtensionCollectionDirectory: [IFUtility pathForInformInternalExtensions:@""]];    // Internal directory of extensions

        downloads = [[NSMutableArray alloc] init];
        numberOfBatchedExtensions = 0;
        numberOfErrors = 0;
        errorString = [[NSMutableString alloc] init];

        self.rebuildAvailableExtensionsCache = YES;
        self.rebuildExtensionDictionaryCache = YES;
        self.cacheChanged = NO;

		// We check for updates every time the application becomes active
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(updateExtensions)
													 name: NSApplicationWillBecomeActiveNotification
												   object: nil];
	}

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];

	 extensionCollectionDirectories = nil;
     downloads =  nil;
     errorString = nil;
    
}

// = Setting up =

- (void) addExtensionCollectionDirectory: (NSString*) directory {
	[extensionCollectionDirectories addObject: directory];
}

- (void) dirtyCache {
    self.rebuildExtensionDictionaryCache = YES;
    self.rebuildAvailableExtensionsCache = YES;
}

// Returns a dictionary where key is author name, value is an array of directory paths for that author
- (NSDictionary*) extensionDictionary {
	if (!self.rebuildExtensionDictionaryCache && cacheExtensionDictionary) {
        return cacheExtensionDictionary;
    }

	NSFileManager* manager = [NSFileManager defaultManager];

	// Retrieve the extensions that exist in the directory
	NSMutableDictionary* resultSet = [NSMutableDictionary dictionary];
	
	// Look through the directories
	for( NSString* extnDir in extensionCollectionDirectories ) {
        NSError* error;
		NSArray* extnFiles = [manager contentsOfDirectoryAtPath: extnDir
                                                          error: &error];
		for( NSString* filename in extnFiles ) {
			NSString* fullPath = [extnDir stringByAppendingPathComponent: filename];

			// Must not be hidden from the finder
			if ([filename characterAtIndex: 0] == '.') {
                continue;
            }

			// 'reserved' is a special case and never shows up in the list
			if ([[filename lowercaseString] isEqualToString: @"reserved"]) {
                continue;
            }

			// Must exist and be a directory
			BOOL exists;
			BOOL isDir;

			exists = [manager fileExistsAtPath: fullPath
								   isDirectory: &isDir];

			if (exists && isDir) {
				// Add to the list of paths for this name
				NSString* filenameKey = [filename lowercaseString];
				NSMutableArray* dirsWithName = resultSet[filenameKey];

				if (dirsWithName == nil) {
                    dirsWithName = [NSMutableArray array];
                }

				[dirsWithName addObject: fullPath];

				// Add to the result
				resultSet[filenameKey] = dirsWithName;
			}
		}
	}

    // Cache the results
    NSDictionary* newExtensionDictionary = resultSet;

    // Compare dictionaries
    if( ![ cacheExtensionDictionary isEqualTo: newExtensionDictionary] ) {
        self.cacheChanged = YES;
    }

    cacheExtensionDictionary = newExtensionDictionary;
    self.rebuildExtensionDictionaryCache = NO;
    
	return resultSet;
}

-(BOOL) isBuiltIn:(NSString*) fullPath {
    int count = 0;
	for( NSString* extnDir in extensionCollectionDirectories ) {
        if( [fullPath startsWith: extnDir] ) {
            if (count >= userLibraryCount ) {
                return YES;
            }
            return NO;
        }
        count++;
    }
    return NO;
}

-(BOOL) isFileInstalled:(NSString*) fullPath {
	for( NSString* extnDir in extensionCollectionDirectories ) {
        if( [fullPath startsWith: extnDir] ) {
            return YES;
        }
    }
    return NO;
}

// Get an array of the available extension information
- (NSArray*) availableExtensions {
	// Use the cached version if it's around
	if (!self.rebuildAvailableExtensionsCache && cacheAvailableExtensions) {
        return cacheAvailableExtensions;
    }

	NSFileManager* manager            = [NSFileManager defaultManager];
	NSDictionary* extensionDictionary = [self extensionDictionary];
	NSMutableArray* result            = [NSMutableArray array];

    // Go through authors
	for( NSString* authorName in extensionDictionary ) {
		NSArray* authorPaths = extensionDictionary[authorName];

        // For each path of an author
        for(NSString* authorPath in authorPaths) {
            NSString* title;
            NSString* author;
            NSString* version;

            NSError* error;
            NSArray* extnFiles = [manager contentsOfDirectoryAtPath: authorPath
                                                              error: &error];
            // For each extension file
            for( NSString* filename in extnFiles ) {
                NSString* fullFilepath = [authorPath stringByAppendingPathComponent: filename];

                // Must not be hidden from the finder
                if ([filename characterAtIndex: 0] == '.') {
                    continue;
                }

                NSString* fileExtension = [[filename pathExtension] lowercaseString];
                if ([fileExtension isEqualToString: @"i7x"] ||
                    [fileExtension isEqualToString: @""]) {
                    // Get information about the extension
                    BOOL gotInfo = [self infoForNaturalInformExtension: fullFilepath
                                                                author: &author
                                                                 title: &title
                                                               version: &version];
                    BOOL isBuiltIn = [self isBuiltIn: fullFilepath];

                    if( gotInfo ) {
                        IFExtensionInfo* info = [[IFExtensionInfo alloc] initWithDisplayName: title
                                                                                    filepath: fullFilepath
                                                                                      author: author
                                                                                     version: version
                                                                                     md5Hash: nil
                                                                                   isBuiltIn: isBuiltIn];
                        [result addObject: info];
                    }
                }
            }
        }
	}

    // Remember this result in cache
    NSArray* newAvailableExtensions = result;
    
    if( ![cacheAvailableExtensions isEqualToArray: newAvailableExtensions] ) {
        self.cacheChanged = YES;
    }
    
    cacheAvailableExtensions = newAvailableExtensions;
    self.rebuildAvailableExtensionsCache = NO;

	return result;
}

- (NSArray*) availableAuthors {
    NSMutableArray* authors = [NSMutableArray array];

    for( IFExtensionInfo* info in [self availableExtensions] ) {
        if( ![authors containsObject: info.author] ) {
            [authors addObject: info.author];
        }
    }
	[authors sortUsingSelector: @selector(caseInsensitiveCompare:)];
    return authors;
}

- (NSArray*) availableExtensionsByAuthor:(NSString*) author {
    NSMutableArray* extensions = [NSMutableArray array];

    for( IFExtensionInfo* info in [self availableExtensions] ) {
        if([[info.author lowercaseString] isEqualToString:[author lowercaseString]]) {
            [extensions addObject:info];
        }
    }
	[extensions sortUsingSelector: @selector(caseInsensitiveCompare:)];
    return extensions;
}







// Returns the array of full extension pathnames for a given extension directory (author) name
- (NSArray*) filesInExtensionWithName: (NSString*) name {
	// Returns all the files in a particular extension (as full path names)
	NSFileManager* manager = [NSFileManager defaultManager];
	NSArray* pathsToSearch;
	
	// Work out which paths to search (just one if we're not merging)
    pathsToSearch = [self extensionDictionary][[name lowercaseString]];

	// Search all the paths to generate the list of files
	// If a file with the same name exists in multiple places, then only the first one is used
	NSMutableDictionary* resultDict = [NSMutableDictionary dictionary];

	for( NSString* path in pathsToSearch ) {
		// Search this path
        NSError* error;
		NSArray* files = [manager contentsOfDirectoryAtPath: path
                                                      error: &error];
		for(NSString* file in files) {
			// Add to the result
			resultDict[[file lowercaseString]] = [path stringByAppendingPathComponent: file];
		}
	}

    // Sort
	NSMutableArray* result = [[resultDict allValues] mutableCopy];
	[result sortUsingSelector: @selector(caseInsensitiveCompare:)];

	return result;
}

// Returns full filepaths for files we can open in the given extension directory (author) name
- (NSArray*) sourceFilesInExtensionWithName: (NSString*) name {
	NSFileManager* manager = [NSFileManager defaultManager];

	// Filter for valid source files
	NSMutableArray* result = [NSMutableArray array];

	NSArray* files = [self filesInExtensionWithName: name];
	for(NSString* file in files) {
		// File must exist and not be a directory
		BOOL exists;
        BOOL isDir;

		exists = [manager fileExistsAtPath: file
							   isDirectory: &isDir];
		if (!exists || isDir) {
            continue;
        }

		// File must not begin with a '.'
		if ([[file lastPathComponent] characterAtIndex: 0] == '.') {
            continue;
        }

		// File must have a suitable extension
		NSString* extn = [[file pathExtension] lowercaseString];
        BOOL isOpenable = [extn isEqualToString: @""]    ||
                          [extn isEqualToString: @"i7x"] ||
                          [extn isEqualToString: @"txt"] ||
                          [extn isEqualToString: @"rtf"] ||
                          [extn isEqualToString: @"rtfd"] ||
                          [extn isEqualToString: @"inf"] ||
                          [extn isEqualToString: @"h"]   ||
                          [extn isEqualToString: @"i6"];
		if (isOpenable) {
			// Add to the result
			[result addObject: file];
		}
	}

    // Sort alphabetically
	[result sortUsingSelector: @selector(caseInsensitiveCompare:)];

	return result;
}

// Create directories
- (void) createDirectory: (NSString*) dir {
    NSAssert(dir != nil,                   @"Bad directory in createDirectory (1)");
    NSAssert(![dir isEqualToString: @""],  @"Bad directory in createDirectory (2)");
    NSAssert(![dir isEqualToString: @"/"], @"Bad directory in createDirectory (3)");

	BOOL exists;
    BOOL isDir;

	exists = [[NSFileManager defaultManager] fileExistsAtPath: dir
												  isDirectory: &isDir];
	if (exists) return;

    NSError* error;
	[[NSFileManager defaultManager] createDirectoryAtPath: dir
                              withIntermediateDirectories: YES
                                               attributes: nil
                                                    error: &error];
}

- (void) createDefaultExtnDir {
	// Create the directory that will contain the extensions (if necessary)
	NSString* directory = extensionCollectionDirectories[0];
	if (directory == nil) return;

    // Create the directory (and the hierarchy)
	[self createDirectory: directory];
}


// Work out the extension's author, title and version by reading the first line from a given full filepath of a Natural Inform extension file
- (BOOL) infoForNaturalInformExtension: (NSString*) file
                                author: (NSString*__strong*) authorOut
                                 title: (NSString*__strong*) titleOut
                               version: (NSString*__strong*) versionOut {
	NSFileManager* mgr = [NSFileManager defaultManager];
	
	if (authorOut != nil) {
        *authorOut = nil;
    }
	if (titleOut != nil) {
        *titleOut = nil;
    }
    if( versionOut != nil ) {
        *versionOut = nil;
    }

	// Can't do anything with a non-existant file
	BOOL isDir;
	BOOL exists = [mgr fileExistsAtPath: file
							isDirectory: &isDir];
	if (!exists || isDir) return NO;

	// Read the first 1k of the extension
	NSFileHandle* extensionFile = [NSFileHandle fileHandleForReadingAtPath: file];
	NSData* extensionInitialData = [extensionFile readDataOfLength: 1024];
	NSString* extensionString = [[NSString alloc] initWithData: extensionInitialData
                                                       encoding: NSUTF8StringEncoding];
    
    // Fix line endings
    if ([extensionString rangeOfString:@"\r"].location != NSNotFound) {
        extensionString = [extensionString stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
        extensionString = [extensionString stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
    }
    
    // Get the first line
    NSRange range = [extensionString rangeOfString:@"\n"];
    if( range.location != NSNotFound ) {
        extensionString = [extensionString substringToIndex:range.location];
    }

    // Trim whitespace
	extensionString = [extensionString stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];

	// Check that the ending is 'begins here'
    if (![[extensionString lowercaseString] endsWith:@" begins here."]) {
        return NO;
    }

    // Remove the " begins here." from the end
    extensionString = [extensionString substringToIndex: [extensionString length] - [@" begins here." length]];

    // Examples:
    // Version 1 of Title Name by Author Name
    // Another Title Name by Author Name

    // Find version name
    NSString* versionName = nil;
    if( [[extensionString lowercaseString] startsWith:@"version "] ) {
        NSRange versionRange = [extensionString rangeOfString: @" of "
                                                      options: NSCaseInsensitiveSearch];
        versionName     = [extensionString substringToIndex:   versionRange.location];
        
        // Remove the version
        extensionString = [extensionString substringFromIndex: versionRange.location + versionRange.length];
    }

    // Find title name
    NSString* titleName = nil;
    {
        NSRange byPosition = [extensionString rangeOfString: @" by "
                                                    options: NSCaseInsensitiveSearch];
        // Must have a ' by '
        if (byPosition.location == NSNotFound) return NO;

        titleName = [extensionString substringToIndex: byPosition.location];

        // Remove the title
        extensionString = [extensionString substringFromIndex: byPosition.location + byPosition.length];
    }

    // Remainder of string is the author
    NSString* authorName = extensionString;

	authorName  = [authorName  stringByTrimmingWhitespace];
	titleName   = [titleName   stringByTrimmingWhitespace];
	versionName = [versionName stringByTrimmingWhitespace];

    // Remove leading 'The' from extension name
    if( [[titleName lowercaseString] startsWith:@"the "] ) {
        titleName = [titleName substringFromIndex: [@"the " length]];
    }

    // Bail out if there is no author name or title left
    if( ([authorName length] == 0) ||
        ([titleName length]  == 0) ) {
        return NO;
    }

    if(authorOut) {
        *authorOut = authorName;
    }
	if (titleOut) {
        *titleOut = titleName;
    }
    if(versionOut) {
        *versionOut = versionName;
    }
	return YES;
}

// Install the given extension
- (BOOL) installExtension: (NSString*) extensionPath
                finalPath: (NSString*__strong*) finalPathOut
                    title: (NSString*__strong*) titleOut
                   author: (NSString*__strong*) authorOut
                  version: (NSString*__strong*) versionOut
       showWarningPrompts: (BOOL) showWarningPrompts
                   notify: (BOOL) notify {
	if (finalPathOut) {
        *finalPathOut = nil;
    }

	// We can add directories (of all sorts, but with no subdirectories, and no larger than 1Mb total)
	// We can also add .h, .inf and .i6 files on their own, creating a directory to do so
	NSFileManager* mgr = [NSFileManager defaultManager];

	extensionPath = [extensionPath stringByStandardizingPath];

	[self createDefaultExtnDir];

	// Check that file or directory exists
	BOOL exists, isDir;

	exists = [mgr fileExistsAtPath: extensionPath
					   isDirectory: &isDir];
	if (!exists || isDir) {
        return NO;          // Can't add something that does not exist
    }

	NSString* author  = nil;
	NSString* title   = nil;
    NSString* version = nil;

    // Check if it is valid to add the file
    // Inform 7 extensions (i7x) have a first line defining title and author (and optional version number)
    // Try to read out the author and title name to see if this file is valid
    BOOL result = [self infoForNaturalInformExtension: extensionPath
                                               author: &author
                                                title: &title
                                              version: &version];
    if (!result) return NO;

    if( authorOut != nil ) {
        *authorOut = author;
    }
    if( titleOut != nil ) {
        *titleOut = title;
    }
    if( versionOut != nil ) {
        *versionOut = version;
    }

	// We should be able to add the file/directory

	// Try to create the destination. First extensionDirectory should be the writable one
	NSString* directory = extensionCollectionDirectories[0];
	NSString* destDir;

	if (directory == nil) {
        return NO;
    }

    if (author) {
        destDir = [directory stringByAppendingPathComponent: author];
    } else {
        destDir = [directory stringByAppendingPathComponent: [[extensionPath lastPathComponent] stringByDeletingPathExtension]];
    }

	destDir = [destDir stringByStandardizingPath];

	if ([[destDir lowercaseString] isEqualToString: [extensionPath lowercaseString]]) {
        return NO;		// Trying to re-add an extension that already exists
    }

	// If the old directory exists and we're not merging, then move the old directory to the trash
	BOOL oldExists = [mgr fileExistsAtPath: destDir];

	// If the directory does not exist, create it
	if (!oldExists) {
        NSError* error;
		if (![mgr createDirectoryAtPath: destDir
            withIntermediateDirectories: YES
                             attributes: nil
                                  error: &error]) {
			// Can't create the extension directory
			return NO;
		}
	}

    NSString* destFile;

    // Work out the destination filename
    if (title != nil) {
        destFile = title;
    }
    else {
        destFile = [extensionPath lastPathComponent];
    }
    
    destFile = [IFExtensionInfo canonicalTitle: destFile];
    
    // destination file mut not be longer than 50 characters? (Is this true?)
    if ([[destFile stringByDeletingPathExtension] length] > 50) {
        // Extension filenames must be at most 50 characters
        // Remove extension and truncate
        destFile = [[destFile stringByDeletingPathExtension] substringToIndex: 50];
    }

    // Extension must have a .i7x extension
    if (![[destFile pathExtension] isEqualToString: @"i7x"]) {
        destFile = [destFile stringByAppendingPathExtension: @"i7x"];
    }

    NSString* dest = [destDir stringByAppendingPathComponent: destFile];
    if (finalPathOut) {
        *finalPathOut = [dest copy];
    }

    // Are we trying to install over a newer version?
    NSString* existingAuthor;
    NSString* existingTitle;
    NSString* existingVersion;
    result = [self infoForNaturalInformExtension: dest
                                          author: &existingAuthor
                                           title: &existingTitle
                                         version: &existingVersion];
    if (result) {
        if( showWarningPrompts ) {
            if( [[existingTitle lowercaseString] isEqualToString: [title lowercaseString]] ) {
                if( [[existingAuthor lowercaseString] isEqualToString: [author lowercaseString]] ) {
                    if( version == nil ) { version = @"Version 1"; }
                    if( existingVersion == nil ) { existingVersion = @"Version 1"; }
                    
                    NSComparisonResult comparison = [existingVersion compare: version options: (NSStringCompareOptions) (NSNumericSearch | NSCaseInsensitiveSearch)];
                    
                    // WARNING: About to overwrite a later version with an earlier one!
                    if( comparison == NSOrderedDescending ) {
                        NSInteger overwrite = NSRunAlertPanel([NSString stringWithFormat: [IFUtility localizedString: @"Overwrite Extension"], existingTitle, existingAuthor],
                                                        [NSString stringWithFormat: [IFUtility localizedString: @"Overwrite Extension Explanation"], existingVersion, version],
                                                        [IFUtility localizedString: @"Cancel"],
                                                        [IFUtility localizedString: @"Replace"],
                                                        nil,
                                                        nil);
                        if (overwrite != NSAlertAlternateReturn) {
                            return YES;
                        }
                    }
                    else {
                        // WARNING: About to overwrite on earlier or equal version with a later version.
                        NSInteger overwrite = NSRunAlertPanel([NSString stringWithFormat: [IFUtility localizedString: @"Replace Extension"], existingTitle, existingAuthor],
                                                        [NSString stringWithFormat: [IFUtility localizedString: @"Replace Extension Explanation"], existingVersion, version],
                                                        [IFUtility localizedString: @"Cancel"],
                                                        [IFUtility localizedString: @"Replace"],
                                                        nil,
                                                        nil);
                        if (overwrite != NSAlertAlternateReturn) {
                            return YES;
                        }
                    }
                }
            }
        }
    }

    NSError* error;

    // Remove old file at destination
    {
        NSString* destFileWithoutExtension = [dest stringByDeletingPathExtension];

        // Try removing the destination file *without* the i7x file extension (remove old version that may not have had a file extension)
        [mgr removeItemAtPath: destFileWithoutExtension
                        error: &error];

        // Try removing the destination file *with* i7x file extension
        [mgr removeItemAtPath: dest
                        error: &error];
    }

    // Copy new file to destination
    if (![mgr copyItemAtPath: extensionPath
                      toPath: dest
                       error: &error] ) {
        // Couldn't finish installing the extension
        return NO;
    }

	// Success
    [self updateExtensions: @(notify)];
	return YES;
}

// = Data source support functions =

- (void) updateExtensions: (NSNumber*) notify {
    // Calculate fresh available extensions
    [self dirtyCache];
    [self availableExtensions];
    
    // Has the array of available extensions changed?
    if( !self.cacheChanged ) {
        return;
    }
    self.cacheChanged = NO;

    // Tell anything that wants to know that the extensions have been updated
    [[NSNotificationCenter defaultCenter] postNotificationName: IFExtensionsUpdatedNotification
                                                        object: self];

    // Perform a census with the new extensions
    [self startCensus: notify];
}

- (void) updateExtensions {
    [self updateExtensions: @YES];
}

-(void) startCensus:(NSNumber*) notify {
    // Re-run the maintenance tasks
    NSString *compilerPath = [IFUtility pathForCompiler:@""];
    if (compilerPath != nil) {
        NSString* notifyType;
        if( [notify boolValue] ) {
            notifyType = IFCensusFinishedNotification;
        } else {
            notifyType = IFCensusFinishedButDontUpdateExtensionsWebPageNotification;
        }

        NSString* externalPath = [IFUtility pathForInformExternalAppSupport];
        NSArray * arguments = @[@"-census",
                                @"-internal",
                                [IFUtility pathForInformInternalAppSupport:@""],
                                @"-external",
                                externalPath];

        NSLog(@"Compiler Path: %@", compilerPath);
        NSLog(@"Arguments: %@", arguments);

        [[IFMaintenanceTask sharedMaintenanceTask] queueTask: compilerPath
                                               withArguments: arguments
                                                  notifyType: notifyType];
    }
}

// = NSSavePanel delegate methods =

- (BOOL)           panel: (id) sender
	  shouldShowFilename: (NSString *) filename {
	BOOL isDir;
	BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath: filename
													   isDirectory: &isDir];
	
	if (!exists) return NO;
	if (isDir) return YES;
	
	NSString* extn = [[filename pathExtension] lowercaseString];

    if( ![extn isEqualToString: @"i7x"] &&
        ![extn isEqualToString: @""] ) {
        return NO;
    }

	return YES;
}

// = Download and Install =
-(void) addError: (NSString*) message {
    // Log error
    NSLog(@"%@", message);

    numberOfErrors++;

    // Append the new message
    NSString* gap = (numberOfErrors > 1) ? @"\n\n" : @"";
    if( numberOfErrors <= maxErrorMessagesToDisplay ) {
        [errorString appendFormat: @"%@%@", gap, message];
    }
    else if (numberOfErrors == (maxErrorMessagesToDisplay+1) ) {
        [errorString appendString: @"\n\n..."];
    }
}

-(void) startDownloadAndInstallNextInQueue {
    if( [downloads count] > 0 ) {
        IFExtensionDownload* dl = downloads[0];

        [dl startDownloadAndInstall];
    }
}

- (BOOL) downloadAndInstallExtension: (NSURL*) url
                              window: (NSWindow*) aWindow
                      notifyDelegate: (NSObject*) notifyDelegate
                        javascriptId: (NSString*) javascriptId {
    IFExtensionDownload* download = [[IFExtensionDownload alloc] initWithURL: url
                                                                       window: aWindow
                                                               notifyDelegate: notifyDelegate
                                                                 javascriptId: javascriptId];
    if ( download ) {
        [downloads addObject: download];
        numberOfBatchedExtensions++;

        if( [downloads count] == 1 ) {
            // Remove old progress
            if( dlProgress != nil ) {
                if( [download.notifyDelegate isKindOfClass:[IFProjectController class]] ) {
                    [dlProgress stopProgress];
                    [(IFProjectController*) download.notifyDelegate removeProgressIndicator: dlProgress];
                }
            }
            // Create new progress
            dlProgress = [[IFProgress alloc] initWithPriority: IFProgressPriorityExtensions
                                             showsProgressBar: YES
                                                    canCancel: YES];
            if( [download.notifyDelegate isKindOfClass:[IFProjectController class]] ) {
                [(IFProjectController*) download.notifyDelegate addProgressIndicator: dlProgress];
            }
            [dlProgress setMessage: [IFUtility localizedString:@"Installing extension"]];
            [dlProgress startProgress];
            [self startDownloadAndInstallNextInQueue];
        }
        return YES;
    }
    return NO;
}

- (void) downloadAndInstallFinished: (IFExtensionDownload*) download {
    [downloads removeObject: download];

    int done  = numberOfBatchedExtensions - (int) [downloads count];
    int total = numberOfBatchedExtensions;
    float percentage = 100.0f * (float) done / (float) total;
    NSString* message;
    if( numberOfErrors > 0 ) {
        message = [NSString stringWithFormat: [IFUtility localizedString:@"Installed %d of %d (%d failed)"], done - numberOfErrors, total, numberOfErrors];
    } else {
        message = [NSString stringWithFormat: [IFUtility localizedString:@"Installed %d of %d"], done, total];
    }
    [dlProgress setPercentage: percentage];
    [dlProgress setMessage: message];

    // Remove any remaining items if we are we cancelled
    if( dlProgress.isCancelled ) {
        [downloads removeAllObjects];
    }

    // Last one finished downloading?
    if( [downloads count] == 0 ) {

        // Report errors or success - only if we are not cancelled
        if( !dlProgress.isCancelled ) {
            // Were there errors?
            if( numberOfErrors > 0 ) {
                if( numberOfErrors < numberOfBatchedExtensions ) {
                    NSString* messageKey;

                    if( (numberOfBatchedExtensions - numberOfErrors) == 1 ) {
                        messageKey = [NSString stringWithFormat: [IFUtility localizedString: @"One extension installed successfully, %d failed"], numberOfErrors];
                    } else {
                        messageKey = [NSString stringWithFormat: [IFUtility localizedString: @"%d extensions installed successfully, %d failed"], numberOfBatchedExtensions - numberOfErrors, numberOfErrors];
                    }
                    [IFUtility runAlertWindow: download.window
                                    localized: YES
                                      warning: YES
                                        title: messageKey
                                      message: @"%@", errorString];
                } else {
                    if (numberOfBatchedExtensions > 1 ) {
                        [IFUtility runAlertWindow: download.window
                                        localized: YES
                                          warning: YES
                                            title: [NSString stringWithFormat: [IFUtility localizedString: @"Failed to install %d extensions"], numberOfErrors]
                                          message: @"%@", errorString];
                    } else {
                        [IFUtility runAlertWindow: download.window
                                        localized: YES
                                          warning: YES
                                            title: [IFUtility localizedString: @"Failed to install extension"]
                                          message: @"%@", errorString];
                    }
                }
            } else {
                // Show final message
                if( numberOfBatchedExtensions > 1 ) {
                    [IFUtility runAlertInformationWindow: download.window
                                                   title: @"Installation complete"
                                                 message: @"%d extensions installed successfully", numberOfBatchedExtensions];
                } else {
                    [IFUtility runAlertInformationWindow: download.window
                                                   title: @"Installation complete"
                                                 message: @"Extension \"%@\" by %@ (%@) installed successfully", download.title, download.author, [download safeVersion]];
                }
            }
        }

        // Remove progress indicator
        if( [download.notifyDelegate isKindOfClass:[IFProjectController class]] ) {
            [dlProgress stopProgress];
            [(IFProjectController*) download.notifyDelegate removeProgressIndicator: dlProgress];
        }

        numberOfBatchedExtensions = 0;
        numberOfErrors = 0;
        [errorString setString:@""];
    }

    // If this particular download succeeded, tell the IFProjectController so it can update the web page to indicate it's downloaded
    if( download.state == IFExtensionDownloadAndInstallSucceeded ) {
        [self dirtyCache];
        [self availableExtensions];
        
        if( download.notifyDelegate != nil ) {
            if( [download.notifyDelegate isKindOfClass:[IFProjectController class]] ) {
                [(IFProjectController*)download.notifyDelegate extensionUpdated: download.javascriptId];
            }
        }
        self.cacheChanged = NO;
    }

    if( [downloads count] > 0 ) {
        [self performSelector: @selector(startDownloadAndInstallNextInQueue)
                 withObject: nil
                 afterDelay: 0.5];
    }
}

@end
