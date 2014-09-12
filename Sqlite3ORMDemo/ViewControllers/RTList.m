//
//  RTList.m
//  Rodrigo G
//
//  Created by Bakuf on 3/24/14.
//  Copyright (c) 2014 test. All rights reserved.
//

#import "RTList.h"
#import "SODTableInfo.h"
#import "SODSettings.h"

@interface RTList (){
    NSMutableArray *data;
}

- (IBAction)addNew:(id)sender;
- (IBAction)changeOrder:(id)sender;

@property (weak, nonatomic) IBOutlet UITableView *theTableView;
@property (weak, nonatomic) IBOutlet UITextField *txtTitleText;

@end

@implementation RTList

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    data = [SODTableInfo getAllRows];
    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)addNew:(id)sender {
    if (self.txtTitleText.text.length != 0) {
        SODTableInfo *info = [[SODTableInfo alloc] init];
        info.title = self.txtTitleText.text;
        info.date = [[NSDate date] description];
        [info insertRow];
        [data addObject:info];
        [self.theTableView reloadData];
    }
}

- (IBAction)changeOrder:(id)sender {
    [self.theTableView setEditing:YES animated:YES];
}

#pragma mark - TableView Methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return data.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = (UITableViewCell*)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    SODTableInfo *tmpInfo = data[indexPath.row];
    
    cell.textLabel.text = tmpInfo.title;
    cell.detailTextLabel.text = tmpInfo.date;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath {
    // If row is deleted, remove it from the list.
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        SODTableInfo *tmpInfo = data[indexPath.row];
        [tmpInfo deleteRow];
        data = [SODTableInfo getAllRows];
        [self.theTableView reloadData];
    }
    
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField{
    [textField resignFirstResponder];
    return YES;
}


- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath{
    return YES;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath{
    SODTableInfo *tmpInfo = data[fromIndexPath.row];
    SODTableInfo *tmpInfo2 = data[toIndexPath.row];
    NSLog(@"%@,%@",tmpInfo,tmpInfo2);
    [tmpInfo swapOrderWithDataModel:tmpInfo2];
    data = [SODTableInfo getAllRows];
    [self.theTableView reloadData];
}

@end
