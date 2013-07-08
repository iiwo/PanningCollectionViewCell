//
//  T20CollectionViewController.m
//  PanningCollectionViewCell
//
//  Created by Iwo Dziechciarow on 7/8/13.
//  Copyright (c) 2013 TRIP20 LLC. All rights reserved.
//

#import "T20CollectionViewController.h"
#import "HHPanningCollectionViewCell.h"

@interface T20CollectionViewController ()

@end

@implementation T20CollectionViewController

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
	// Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


-(NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView{
    return 1;
}

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    return 10;
}

-(UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath{
    HHPanningCollectionViewCell* cell = [self.collectionView dequeueReusableCellWithReuseIdentifier:@"Cell" forIndexPath:indexPath];
    cell.directionMask = HHPanningCollectionViewCellDirectionLeft + HHPanningCollectionViewCellDirectionRight;
    UIView *drawerView = [[UIView alloc] initWithFrame:cell.frame];
    drawerView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"dark_dotted"]];
    
    cell.drawerView = drawerView;
    return cell;
}

@end
