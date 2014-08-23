//
//  FirstViewController.m
//  Maker Faire Orlando
//
//  Created by Conner Brooks on 7/15/14.
//  Copyright (c) 2014 Conner Brooks. All rights reserved.
//

#import "MakerViewController.h"
#import "AppDelegate.h"
#import "Faire+methods.h"
#import "Maker+methods.h"
#import "makerTableViewCell.h"
#import "MakerDetailViewController.h"
#import "BOZPongRefreshControl.h"

@interface MakerViewController ()
@property (strong, nonatomic) IBOutlet UITableView *tableview;

@property (strong, nonatomic) NSArray *makers;
@property (strong, nonatomic) NSMutableArray *filteredMakers;
@property (weak, nonatomic) IBOutlet UISearchBar *makerSearchBar;
@property (weak, nonatomic) BOZPongRefreshControl *refreshControl;
@property (strong, nonatomic) UILabel *failView;

@property (weak, nonatomic) NSManagedObjectContext *context;
@end

@implementation MakerViewController

@synthesize tableview = _tableview;
@synthesize makers = _makers;
@synthesize context = _context;
@synthesize failView = _failView;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _makerSearchBar.barTintColor = [UIColor makerRed];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(finishRefresh)
                                                 name:kMakersArrived
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refreshFailure)
                                                 name:kMakersFailed
                                               object:nil];
    
    AppDelegate *del = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    _context = [del managedObjectContext];
	
    [self attemptRefresh];
    
    _makers = nil;
    
    [self fillMakers];
}

- (void)viewDidLayoutSubviews
{
    _refreshControl = [BOZPongRefreshControl attachToTableView:_tableview
                                             withRefreshTarget:self
                                              andRefreshAction:@selector(disableForRefresh)];
    __block UILabel *failView = [[UILabel alloc] initWithFrame:CGRectMake(self.view.frame.size.width/2 - 40.0, 11.0, 80.0, 65.0)];
    [failView setText:@"FAIL"];
    [failView setTextAlignment:NSTextAlignmentCenter];
    [failView setFont:[UIFont boldSystemFontOfSize:35.0]];
    [failView setTextColor:[UIColor whiteColor]];
    [failView setHidden:YES];
    [failView setAlpha:0.0];

    _failView = failView;
}

- (void)fillMakers
{
    NSFetchRequest *makersFetch = [[NSFetchRequest alloc] initWithEntityName:@"Maker"];
    
    NSSortDescriptor *sortByName = [[NSSortDescriptor alloc] initWithKey:@"title"
                                                               ascending:YES];
    [makersFetch setSortDescriptors:@[sortByName]];
    
    NSError *fetchError = nil;
    
    _makers = [_context executeFetchRequest:makersFetch error:&fetchError];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [_refreshControl scrollViewDidScroll];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    [_refreshControl scrollViewDidEndDragging];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)disableForRefresh
{
    [_tableview setUserInteractionEnabled:NO];
    [self attemptRefresh];
}

- (void)attemptRefresh
{
    [Maker updateMakers];
}

- (void)finishRefresh
{
    [self fillMakers];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [_refreshControl finishedLoading];
        [_tableview reloadData];
        [_tableview setUserInteractionEnabled:YES];
    });
}

- (void)refreshFailure
{
    // The refresh timed-out, failed for some reason, etc
    
    __weak MakerViewController *weakSelf = self;
    __weak UILabel *weakFailView = _failView;
    
    [_refreshControl setBackgroundColor:[UIColor blackColor]];
    [_failView setAlpha:0.0];
    [_failView setHidden:YES];
    [_refreshControl addSubview:_failView];
    
    [UIView animateWithDuration:1.0 animations:^(void)
    {
        
        [weakFailView setAlpha:1.0];
        [weakFailView setHidden:NO];
        
        [weakSelf.refreshControl setBackgroundColor:[UIColor makerRed]];
        
    } completion:^(BOOL finished)
    {
        [UIView animateWithDuration:0.5 animations:^(void)
         {
             [weakFailView removeFromSuperview];
             [weakSelf.refreshControl setBackgroundColor:[UIColor blackColor]];
             
             [weakSelf.refreshControl finishedLoading];
             [weakSelf.tableview setUserInteractionEnabled:YES];
         }];
    }];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (tableView == self.searchDisplayController.searchResultsTableView) {
        return [_filteredMakers count];
    } else {
        return [_makers count];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    makerTableViewCell *cell = (makerTableViewCell *)[_tableview dequeueReusableCellWithIdentifier:@"tempMakerCell"];
    
    Maker *cellMaker;
    
    if (tableView == self.searchDisplayController.searchResultsTableView) {
        cellMaker = [_filteredMakers objectAtIndex:indexPath.row];
    } else {
        cellMaker = [_makers objectAtIndex:indexPath.row];
    }
    
    [cell.textLabel setText:cellMaker.projectName];
    [cell.detailTextLabel setText:cellMaker.location];
    
    
    return cell;
}


- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    MakerDetailViewController *detailViewController = (MakerDetailViewController*)[segue destinationViewController];
    
    Maker *maker = nil;
    if(self.searchDisplayController.active) {
        NSInteger row = [[self.searchDisplayController.searchResultsTableView indexPathForSelectedRow] row];
        maker = [_filteredMakers objectAtIndex:row];
    }
    else {
        NSInteger row = [[_tableview indexPathForSelectedRow] row];
        maker = [_makers objectAtIndex:row];
    }
    
    [detailViewController setMaker:maker];
}

#pragma mark Content Filtering
-(void)filterContentForSearchText:(NSString*)searchText scope:(NSString*)scope {
    // clear filter array
    [_filteredMakers removeAllObjects];
    // Filter the array
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.projectName contains[c] %@",searchText];
    _filteredMakers = [NSMutableArray arrayWithArray:[_makers filteredArrayUsingPredicate:predicate]];
}

#pragma mark - UISearchDisplayController Delegate Methods
-(BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString {
    // should reload on change
    [self filterContentForSearchText:searchString scope:
     [[self.searchDisplayController.searchBar scopeButtonTitles] objectAtIndex:[self.searchDisplayController.searchBar selectedScopeButtonIndex]]];
    // Return YES to reload table view
    return YES;
}

-(BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchScope:(NSInteger)searchOption {
    // Tells the table data source to reload when text changes
    [self filterContentForSearchText:self.searchDisplayController.searchBar.text scope:
     [[self.searchDisplayController.searchBar scopeButtonTitles] objectAtIndex:searchOption]];
    // Return YES to reload table view
    return YES;
}


@end
