#import "GHFeed.h"
#import "GHFeedEntry.h"
#import "GHUser.h"


@interface GHFeed (PrivateMethods)

- (void)parseFeed;

@end


@implementation GHFeed

@synthesize url, entries, isLoaded, isLoading;

- (id)initWithURL:(NSURL *)theURL {
	if (self = [super init]) {
		self.url = theURL;
		self.entries = [NSMutableArray array];
		self.isLoaded = NO;
		self.isLoading = NO;
	}
	return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<GHFeed url:'%@' isLoading:'%@'>", url, isLoading ? @"YES" : @"NO"];
}

#pragma mark -
#pragma mark Feed parsing

- (void)loadFeed {
	if (self.isLoading) return;
	self.isLoaded = NO;
	self.isLoading = YES;
	self.entries = [NSMutableArray array];
	[self performSelectorInBackground:@selector(parseFeed) withObject:nil];
}

- (void)parseFeed {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSXMLParser *parser = [[NSXMLParser alloc] initWithContentsOfURL:url];
	[parser setDelegate:self];
	[parser setShouldProcessNamespaces:NO];
	[parser setShouldReportNamespacePrefixes:NO];
	[parser setShouldResolveExternalEntities:NO];
	[parser parse];
	[parser release];
	[pool release];
}

- (void)finishedParsing {
	self.isLoading = NO;
	self.isLoaded = YES;
}

#pragma mark -
#pragma mark NSXMLParser delegation methods

- (void)parserDidStartDocument:(NSXMLParser *)parser {
	dateFormatter = [[NSDateFormatter alloc] init];
	dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss";
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict {
	if ([elementName isEqualToString:@"entry"]) {
		currentEntry = [[GHFeedEntry alloc] init];
		currentEntry.feed = self;
	} else if ([elementName isEqualToString:@"link"]) {
		NSString *href = [attributeDict valueForKey:@"href"];
		currentEntry.linkURL = ([href isEqualToString:@""]) ? nil : [NSURL URLWithString:href];
	}
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {	
	if (!currentElementValue) {
		string = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		currentElementValue = [[NSMutableString alloc] initWithString:string];
	} else {
		string = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		[currentElementValue appendString:string];
	}
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
	if ([elementName isEqualToString:@"entry"]) {
		[entries addObject:currentEntry];
		[currentEntry release];
		currentEntry = nil;
	} else if ([elementName isEqualToString:@"id"]) {
		NSString *value = [currentElementValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		NSString *event = [value substringFromIndex:20];
		currentEntry.entryID = value;
		if ([event hasPrefix:@"Fork"]) {
			currentEntry.eventType = @"fork";
		} else if ([event hasPrefix:@"Follow"]) {
			currentEntry.eventType = @"follow";
		} else if ([event hasPrefix:@"CommitComment"]) {
			currentEntry.eventType = @"comment";
		} else if ([event hasPrefix:@"Commit"]) {
			currentEntry.eventType = @"commit";
		} else if ([event hasPrefix:@"Watch"]) {
			currentEntry.eventType = @"watch";
		} else if ([event hasPrefix:@"Delete"]) {
			currentEntry.eventType = @"delete";
		} else if ([event hasPrefix:@"Create"]) {
			currentEntry.eventType = @"create";
		} else if ([event hasPrefix:@"ForkApply"]) {
			currentEntry.eventType = @"merge";
		} else if ([event hasPrefix:@"Member"]) {
			currentEntry.eventType = @"member";
		} else if ([event hasPrefix:@"Push"]) {
			currentEntry.eventType = @"push";
		} else if ([event hasPrefix:@"Gist"]) {
			currentEntry.eventType = @"gist";
		} else if ([event hasPrefix:@"Wiki"]) {
			currentEntry.eventType = @"wiki";
		} else {
			currentEntry.eventType = nil;
		}
	} else if ([elementName isEqualToString:@"updated"]) {
		currentEntry.date = [dateFormatter dateFromString:currentElementValue];
	} else if ([elementName isEqualToString:@"title"] || [elementName isEqualToString:@"content"]) {
		[currentEntry setValue:currentElementValue forKey:elementName];
	} else if ([elementName isEqualToString:@"name"]) {
		GHUser *user = [[GHUser alloc] initWithLogin:currentElementValue];
		currentEntry.user = user;
		[user release];
	} 
	[currentElementValue release];
	currentElementValue = nil;
}

- (void)parserDidEndDocument:(NSXMLParser *)parser {
	[dateFormatter release];
	dateFormatter = nil;
	[self performSelectorOnMainThread:@selector(finishedParsing) withObject:nil waitUntilDone:NO];
}

// FIXME It's not quite perfect that the error handling is part
// of the model layer. This should happen in the controller.
- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError {
	#ifdef DEBUG
	NSLog(@"Parsing error: %@", [parseError localizedDescription]);
	#endif
	// Let's just assume it's an authentication error
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Authentication error" message:@"Please revise the settings and check your username and API token" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
	[alert release];
}

#pragma mark -
#pragma mark Cleanup

- (void)dealloc {
	[url release];
	[entries release];
	[dateFormatter release];
	[currentElementValue release];
	[currentEntry release];
    [super dealloc];
}

@end