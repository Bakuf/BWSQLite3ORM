//
//  BWViewController.m
//  BWSQlite3ORM
//
//  Created by Rodrigo Galvez on 03/16/2021.
//  Copyright (c) 2021 Rodrigo Galvez. All rights reserved.
//

#import "BWViewController.h"
#import "BWTableInfo.h"

@interface BWViewController ()<UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource>{
    NSMutableArray *data;
    NSIndexPath *selectedIndexPath;
}

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UITextField *textField;

@end

@implementation BWViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.textField.delegate = self;
    self.textField.returnKeyType = UIReturnKeyDone;
    data = [[NSMutableArray alloc] init];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)viewWillAppear:(BOOL)animated{
    [self fetchRecordsAndReload];
}

- (void)fetchRecordsAndReload{
    [BWTableInfo getAllRowsWithResult:^(BOOL success, NSString *error, NSMutableArray *results) {
        if (success) {
            data = results;
            [self.tableView reloadData];
        }else{
            NSLog(@"Error fetching BWTableInfo Rows : %@",error);
        }
    }];
}

- (void)addNewRow{
    if (self.textField.text.length != 0) {
        BWTableInfo *info = [[BWTableInfo alloc] init];
        info.title = self.textField.text;
        info.date = [[NSDate date] description];
        [info insertRow];
        [self fetchRecordsAndReload];
    }
}

- (void)updateRow{
    if (self.textField.text.length != 0 && selectedIndexPath != nil) {
        BWTableInfo *info = data[selectedIndexPath.row];
        info.title = self.textField.text;
        info.date = [[NSDate date] description];
        [info updateRow];
        [self fetchRecordsAndReload];
    }
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
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
    BWTableInfo *tmpInfo = data[indexPath.row];
    
    cell.textLabel.text = tmpInfo.title;
    cell.detailTextLabel.text = tmpInfo.date;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    if (selectedIndexPath != nil) {
        [tableView deselectRowAtIndexPath:indexPath animated:NO];
        if (selectedIndexPath.row == indexPath.row) {
            selectedIndexPath = nil;
            self.textField.text = @"";
            return;
        }
    }
    selectedIndexPath = indexPath;
    BWTableInfo *tmpInfo = data[indexPath.row];
    self.textField.text = tmpInfo.title;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        BWTableInfo *tmpInfo = data[indexPath.row];
        [tmpInfo deleteRow];
        [self fetchRecordsAndReload];
    }
    
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField{
    [textField resignFirstResponder];
    if (selectedIndexPath != nil) {
        [self updateRow];
    }else{
        [self addNewRow];
    }
    return YES;
}


- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath{
    return YES;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath{
    BWTableInfo *tmpInfo = data[fromIndexPath.row];
    BWTableInfo *tmpInfo2 = data[toIndexPath.row];
    NSLog(@"%@,%@",tmpInfo,tmpInfo2);
    [tmpInfo swapOrderWithDataModel:tmpInfo2];
    [self fetchRecordsAndReload];
}

@end
