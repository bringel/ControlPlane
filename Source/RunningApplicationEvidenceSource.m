//
//  RunningApplicationEvidenceSource.m
//  ControlPlane
//
//  Created by David Symonds on 23/5/07.
//

#import "RunningApplicationEvidenceSource.h"
#import "DSLogger.h"


@implementation RunningApplicationEvidenceSource

- (id)init
{
	if (!(self = [super init]))
		return nil;

	applications = [[NSMutableArray alloc] init];

	return self;
}

- (void)dealloc
{
	[applications release];

	[super dealloc];
}

- (void)doFullUpdate
{
    NSArray *runningApps = [[NSWorkspace sharedWorkspace] runningApplications];

	NSMutableArray *apps = [[NSMutableArray alloc] initWithCapacity:[runningApps count]];

	for (NSRunningApplication *runningApp in runningApps) {
		NSString *identifier = [runningApp bundleIdentifier];
		NSString *name = [runningApp localizedName];
        
        // some programs, like mdworker, don't have a bundleIdentifier
        if ([identifier length] == 0) 
            identifier = [runningApp localizedName];
        
        if ([identifier length] != 0)
            [apps addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                             identifier, @"identifier", name, @"name", nil]];
	}

	[lock lock];
	[applications setArray:apps];
	[self setDataCollected:[applications count] > 0];
#ifdef DEBUG_MODE
	DSLog(@"Running apps:\n%@", applications);
#endif
	[lock unlock];
	
	[apps release];
}

- (void)start
{
	if (running)
		return;

	// register for notifications
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
							       selector:@selector(doFullUpdate)
								   name:NSWorkspaceDidLaunchApplicationNotification
								 object:nil];
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
							       selector:@selector(doFullUpdate)
								   name:NSWorkspaceDidTerminateApplicationNotification
								 object:nil];

	[self doFullUpdate];

	running = YES;
}

- (void)stop
{
	if (!running)
		return;

	// remove notifications
	[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self
								      name:nil
								    object:nil];

	[lock lock];
	[applications removeAllObjects];
	[self setDataCollected:NO];
	[lock unlock];

	running = NO;
}

- (NSString *)name
{
	return @"RunningApplication";
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule
{
	NSString *param = [rule valueForKey:@"parameter"];
	BOOL match = NO;

	[lock lock];
	NSEnumerator *en = [applications objectEnumerator];
	NSDictionary *dict;
	while ((dict = [en nextObject])) {
		if ([[dict valueForKey:@"identifier"] isEqualToString:param]) {
			match = YES;
			break;
		}
	}
	[lock unlock];

	return match;
}

- (NSString *)getSuggestionLeadText:(NSString *)type
{
	return NSLocalizedString(@"The following application running", @"In rule-adding dialog");
}

- (NSArray *)getSuggestions
{
	[lock lock];
	NSMutableArray *array = [NSMutableArray arrayWithCapacity:[applications count]];

	NSEnumerator *en = [applications objectEnumerator];
	NSDictionary *dict;
	while ((dict = [en nextObject])) {
		NSString *identifier = [dict valueForKey:@"identifier"];
		NSString *desc = [NSString stringWithFormat:@"%@ (%@)", [dict valueForKey:@"name"], identifier];
		[array addObject:
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"RunningApplication", @"type",
				identifier, @"parameter",
				desc, @"description", nil]];
	}
	[lock unlock];

	return array;
}

- (NSString *) friendlyName {
    return NSLocalizedString(@"Running Application", @"");
}

@end
