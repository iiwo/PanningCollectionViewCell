/*
 * Copyright (c) 2012, Pierre Bernard & Houdah Software s.à r.l.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the <organization> nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

#import "HHPanningCollectionViewCell.h"

#import "HHDirectionPanGestureRecognizer.h"
#import "HHInnerShadowView.h"

#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>


#define HH_PANNING_ANIMATION_DURATION		0.1f
#define HH_PANNING_BOUNCE_DISTANCE			10.0f
#define HH_PANNING_MINIMUM_PAN				50.0f
#define HH_PANNING_MAXIMUM_PAN              0.0f // Set to 0.0f for full view width
#define HH_PANNING_REVEAL_DISTANCE          0.0f // Set to 0.0f to hide the cell completely
#define HH_PANNING_TRIGGER_OFFSET			100.0f
#define HH_PANNING_USE_VELOCITY             YES


@interface HHPanningCollectionViewCell () <UIGestureRecognizerDelegate>

@property (nonatomic, assign, getter = isDrawerRevealed) BOOL drawerRevealed;
@property (nonatomic, assign, getter = isAnimationInProgress) BOOL animationInProgress;

@property (nonatomic, strong) UIView* containerView;
@property (nonatomic, strong) UIView* shadowView;
@property (nonatomic, strong) UIPanGestureRecognizer* panGestureRecognizer;
@property (nonatomic, assign) CGFloat panOriginX;
@property (nonatomic, assign, getter = isPanning) BOOL panning;

- (void)panningCollectionViewCellInit;

- (UIView*)createContainerView;
- (UIView*)createShadowView;
- (UIPanGestureRecognizer*)createPanGesureRecognizer;

- (void)setDrawerRevealed:(BOOL)revealed direction:(HHPanningCollectionViewCellDirection)direction animated:(BOOL)animated;

- (void)updateShadowFrame;

@end


static NSString * const kDrawerRevealedContext = @"drawerRevealed";
static NSString * const kContainerFrameContext = @"containerFrame";

static HHPanningCollectionViewCellDirection HHOppositeDirection(HHPanningCollectionViewCellDirection direction);


@implementation HHPanningCollectionViewCell

#pragma mark -
#pragma mark Initialization

- (id)init
{
    self = [super init];

	if (self != nil) {
		[self panningCollectionViewCellInit];
	}

    return self;
}

- (id)initWithCoder:(NSCoder*)coder
{
	self = [super initWithCoder:coder];

	if (self != nil) {
		[self panningCollectionViewCellInit];
	}

    return self;
}

- (void)panningCollectionViewCellInit
{
	self.containerView = [self createContainerView];
	self.shadowView = [self createShadowView];
	self.panGestureRecognizer = [self createPanGesureRecognizer];

	[self addGestureRecognizer:self.panGestureRecognizer];

	self.directionMask = 0;
	self.shouldBounce = YES;

    self.minimumPan = HH_PANNING_MINIMUM_PAN;
    self.maximumPan = HH_PANNING_MAXIMUM_PAN;
    self.revealDistance = HH_PANNING_REVEAL_DISTANCE;

	[self addObserver:self forKeyPath:@"drawerRevealed" options:0 context:(__bridge void *)kDrawerRevealedContext];
	[self addObserver:self forKeyPath:@"containerView.frame" options:0 context:(__bridge void *)kContainerFrameContext];
}

- (void)awakeFromNib
{
	if ([super respondsToSelector:@selector(awakeFromNib)]) {
		[super awakeFromNib];
	}
}

- (void)prepareForReuse
{
	[super prepareForReuse];

    self.delegate = nil;

	[self setDrawerRevealed:NO animated:NO];

    self.directionMask = 0;
	self.shouldBounce = YES;

    self.drawerRevealed = NO;
    self.animationInProgress = NO;

    self.panOriginX = 0.0f;
    self.panning = NO;
}

- (UIView*)createContainerView
{
	UIView* containerView = [[UIView alloc] initWithFrame:self.bounds];

	[containerView setOpaque:YES];
	[containerView setAutoresizesSubviews:YES];
	[containerView setAutoresizingMask:UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight];

	[containerView setBackgroundColor:[UIColor whiteColor]];

	return containerView;
}

- (UIView*)createShadowView
{
	UIView* shadowView = [[HHInnerShadowView alloc] initWithFrame:self.bounds];

	[shadowView setOpaque:NO];
	[shadowView setUserInteractionEnabled:NO];
	[shadowView setAutoresizesSubviews:YES];
	[shadowView setAutoresizingMask:UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight];

	return shadowView;
}

- (UIPanGestureRecognizer*)createPanGesureRecognizer
{
	HHDirectionPanGestureRecognizer* gestureRecognizer = [[HHDirectionPanGestureRecognizer alloc] initWithTarget:self
																										  action:@selector(gestureRecognizerDidPan:)];

	gestureRecognizer.direction = HHDirectionPanGestureRecognizerHorizontal;
	gestureRecognizer.delegate = self;
	
	return gestureRecognizer;
}


#pragma mark -
#pragma mark Finalization

- (void)dealloc
{
	[self removeObserver:self forKeyPath:@"drawerRevealed" context:(__bridge void *)kDrawerRevealedContext];
	[self removeObserver:self forKeyPath:@"containerView.frame" context:(__bridge void *)kContainerFrameContext];
}


#pragma mark -
#pragma mark Accessors

@synthesize drawerView = _drawerView;

@synthesize directionMask = _directionMask;
@synthesize shouldBounce = _shouldBounce;
@synthesize minimumPan = _minimumPan;
@synthesize maximumPan = _maximumPan;

@synthesize drawerRevealed = _drawerRevealed;
@synthesize animationInProgress = _animationInProgress;

@synthesize containerView = _containerView;
@synthesize shadowView = _shadowView;
@synthesize panGestureRecognizer = _panGestureRecognizer;

@synthesize panOriginX = _panOriginX;
@synthesize panning = _panning;

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == (__bridge void *)kDrawerRevealedContext) {
		if (self.drawerRevealed) {
			UIView* CollectionView = [self superview];

			if ([CollectionView isKindOfClass:[UICollectionView class]]) {
				for (UICollectionViewCell *cell in [(UICollectionView*)CollectionView visibleCells]) {
					if ((cell != self) && [cell isKindOfClass:[HHPanningCollectionViewCell class]]) {
						[(HHPanningCollectionViewCell*)cell setDrawerRevealed:NO animated:YES];
					}
				}
			}
		}
	}
    else if (context == (__bridge void *)kContainerFrameContext) {
		[self updateShadowFrame];
	}
	else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}


#pragma mark -
#pragma mark API

- (void)setSelected:(BOOL)selected
{
	[super setSelected:selected];
}

- (void)setHighlighted:(BOOL)highlighted
{
	if (highlighted && [self isDrawerRevealed]) {
		return;
	}

	[super setHighlighted:highlighted];
}

- (void)setDrawerRevealed:(BOOL)revealed animated:(BOOL)animated
{
	NSInteger directionMask = self.directionMask;

	if (HHPanningCollectionViewCellDirectionRight & directionMask) {
		[self setDrawerRevealed:revealed direction:HHPanningCollectionViewCellDirectionRight animated:animated];
	}
	else if (HHPanningCollectionViewCellDirectionLeft & directionMask) {
		[self setDrawerRevealed:revealed direction:HHPanningCollectionViewCellDirectionLeft animated:animated];
	}
}

- (void)setDrawerRevealed:(BOOL)revealed direction:(HHPanningCollectionViewCellDirection)direction animated:(BOOL)animated
{
	if (self.drawerView == nil) {
		return;
	}

	self.drawerRevealed = revealed;

	UIView *drawerView = self.drawerView;
	UIView *shadowView = self.shadowView;
	UIView *containerView = self.containerView;
	CGRect frame = [containerView frame];

	UIView *cellView = self;
	CGRect bounds = [cellView bounds];
	CGFloat duration = animated ? HH_PANNING_ANIMATION_DURATION : 0.0f;

	[cellView addSubview:drawerView];
	[cellView addSubview:shadowView];
	[cellView addSubview:containerView];

	if (revealed) {
		if (direction == HHPanningCollectionViewCellDirectionRight) {
			frame.origin.x = self.revealDistance > 0 ?
                bounds.origin.x + self.revealDistance :
                bounds.origin.x + bounds.size.width;
		}
		else {
			frame.origin.x = self.revealDistance > 0 ?
                bounds.origin.x - self.revealDistance :
                bounds.origin.x - bounds.size.width;
		}

		self.animationInProgress = YES;

        void (^animations)(void) = ^ {
            [containerView setFrame:frame];
        };

        void (^completion)(BOOL finished) = ^(BOOL finished) {
            if (self.revealDistance == 0) {
                [containerView removeFromSuperview];
            }

            self.animationInProgress = NO;
        };

        if (animated) {
            [UIView animateWithDuration:HH_PANNING_ANIMATION_DURATION
                                  delay:0.0f
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:animations
                             completion:completion];
        }
        else {
            animations();
            completion(YES);
        }
	}
	else {
		frame.origin.x = 0.0;

        void (^animations)(void) = ^ {
            [containerView setFrame:frame];
        };

        self.animationInProgress = YES;

        void (^completion)(BOOL finished) = ^(BOOL finished) {
            [drawerView removeFromSuperview];
            [shadowView removeFromSuperview];

            self.animationInProgress = NO;
        };

        if (animated) {
            BOOL shouldBounce = self.shouldBounce;

            if (shouldBounce) {
                CGFloat bounceDuration = duration;
                CGFloat offsetX = containerView.frame.origin.x;
                CGFloat bounceMultiplier = fminf(fabsf(offsetX / HH_PANNING_TRIGGER_OFFSET), 1.0f);
                CGFloat bounceDistance = bounceMultiplier * HH_PANNING_BOUNCE_DISTANCE;

                if (offsetX < 0.0f) {
                    bounceDistance *= -1.0;
                }

                [UIView animateWithDuration:duration
                                      delay:0.0f
                                    options:UIViewAnimationOptionCurveEaseOut
                                 animations:animations
                                 completion:^(BOOL finished) {
                                     [UIView animateWithDuration:bounceDuration
                                                           delay:0.0f
                                                         options:UIViewAnimationOptionCurveLinear
                                                      animations:^{
                                                          [containerView setFrame:CGRectOffset(frame, bounceDistance, 0.0f)];
                                                      } completion:^(BOOL finished) {
                                                          [UIView animateWithDuration:bounceDuration
                                                                                delay:0.0f
                                                                              options:UIViewAnimationOptionCurveLinear
                                                                           animations:animations
                                                                           completion:completion];
                                                      }];
                                 }];
            }
            else {
                [UIView animateWithDuration:duration
                                      delay:0.0f
                                    options:UIViewAnimationOptionCurveEaseOut
                                 animations:animations
                                 completion:completion];
            }
        }
        else {
            animations();
            completion(YES);
        }
	}
}


#pragma mark -
#pragma mark Gesture recognizer

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
	return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer*)gestureRecognizer shouldReceiveTouch:(UITouch*)touch
{
	BOOL shouldReceiveTouch = (! self.animationInProgress) && (self.drawerView != nil);

    if (shouldReceiveTouch) {
        UICollectionView* CollectionView = (id)[self superview];

        if ([CollectionView isKindOfClass:[UICollectionView class]]) {
            shouldReceiveTouch = ! (CollectionView.isDragging || CollectionView.isDecelerating);
        }
    }

    if (shouldReceiveTouch) {
        id<HHPanningCollectionViewCellDelegate> delegate = self.delegate;

        if ([delegate respondsToSelector:@selector(panningCollectionViewCell:shouldReceivePanningTouch:)]) {
            shouldReceiveTouch  = [delegate panningCollectionViewCell:self shouldReceivePanningTouch:touch];
        }
    }

    return shouldReceiveTouch;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer*)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer*)otherGestureRecognizer
{
	if ([gestureRecognizer isKindOfClass:[HHDirectionPanGestureRecognizer class]]) {
		HHDirectionPanGestureRecognizer *panGestureRecognizer = (HHDirectionPanGestureRecognizer*)gestureRecognizer;

		return (!panGestureRecognizer.panRecognized);
	}

    return YES;
}

- (void)gestureRecognizerDidPan:(UIPanGestureRecognizer*)gestureRecognizer
{
    if (self.animationInProgress) {
		return;
	}

	UIGestureRecognizerState state = gestureRecognizer.state;

	if (state == UIGestureRecognizerStateBegan) {
		UIView *drawerView = self.drawerView;
		UIView *shadowView = self.shadowView;
		UIView *containerView = self.containerView;

		[self addSubview:drawerView];
		[self addSubview:shadowView];
		[self addSubview:containerView];
		[self setSelected:NO];

		self.panOriginX = containerView.frame.origin.x;
		self.panning = NO;
	}
	else if (state == UIGestureRecognizerStateChanged) {
		CGPoint translation = [gestureRecognizer translationInView:self];
		CGFloat totalPanX = translation.x;

		if (!self.panning) {
			if (fabsf(totalPanX) <= self.minimumPan) {
				totalPanX = 0.0f;
			}
			else {
				self.panning = YES;
			}
		}

		UIView *containerView = self.containerView;
		CGRect containerViewFrame = [containerView frame];

		containerViewFrame.origin.x = self.panOriginX + totalPanX;

        CGFloat maximumPan = self.maximumPan;
        CGFloat width = (maximumPan > 0.0f) ? maximumPan : self.bounds.size.width;
		NSInteger directionMask = self.directionMask;
		CGFloat leftLimit = (directionMask & HHPanningCollectionViewCellDirectionLeft) ? (-1.0 * width) : 0.0f;
		CGFloat rightLimit = (directionMask & HHPanningCollectionViewCellDirectionRight) ? width : 0.0f;

		if (containerViewFrame.origin.x <= leftLimit) {
			containerViewFrame.origin.x = leftLimit;
		}
		else if (containerViewFrame.origin.x >= rightLimit) {
			containerViewFrame.origin.x = rightLimit;
		}

		[containerView setFrame:containerViewFrame];
	}
    else if ((state == UIGestureRecognizerStateEnded) || (state == UIGestureRecognizerStateCancelled)) {
		BOOL drawerRevealed = self.drawerRevealed;
		BOOL drawerWasRevealed = drawerRevealed;

		CGPoint translation = [gestureRecognizer translationInView:self];
		CGFloat totalPanX = translation.x;
		CGFloat panOriginX = self.panOriginX;
		BOOL isOffsetRight = (panOriginX > 0.0);
		HHPanningCollectionViewCellDirection panDirection = (totalPanX > 0.0f) ? HHPanningCollectionViewCellDirectionRight : HHPanningCollectionViewCellDirectionLeft;
		HHPanningCollectionViewCellDirection normalizedPanDirection = drawerRevealed ? HHOppositeDirection(panDirection) : panDirection;
		NSInteger directionMask = self.directionMask;
        id<HHPanningCollectionViewCellDelegate> delegate = self.delegate;
        BOOL isDelegateTrigger = [delegate respondsToSelector:@selector(panningCollectionViewCell:didTriggerWithDirection:)];

		if (drawerRevealed) {
			directionMask = isOffsetRight ? HHPanningCollectionViewCellDirectionRight : HHPanningCollectionViewCellDirectionLeft;
		}

		if (normalizedPanDirection & directionMask) {
			CGFloat triggerOffset = HH_PANNING_TRIGGER_OFFSET;

			if (fabsf(totalPanX) > triggerOffset) {
				drawerRevealed = !drawerRevealed;
			}
			else if (HH_PANNING_USE_VELOCITY) {
				CGPoint velocity = [gestureRecognizer velocityInView:self];
				CGFloat velocityX = velocity.x;

				if (fabsf(velocityX) > triggerOffset) {
					drawerRevealed = !drawerRevealed;
				}
			}
		}

		HHPanningCollectionViewCellDirection direction = panDirection;

		if (drawerRevealed == drawerWasRevealed) {
			direction = isOffsetRight ? HHPanningCollectionViewCellDirectionRight : HHPanningCollectionViewCellDirectionLeft;
		}

        if (isDelegateTrigger && (drawerRevealed != drawerWasRevealed)) {
            [self setDrawerRevealed:NO direction:direction animated:YES];

            [delegate panningCollectionViewCell:self didTriggerWithDirection:panDirection];
        }
        else {
            [self setDrawerRevealed:drawerRevealed direction:direction animated:YES];
        }

		self.panning = NO;
	}
}

- (void)layoutSubviews
{
	[super layoutSubviews];

    if (self.isPanning) {
        return;
    }

	UIView* cellView = self;
	UIView* containerView = self.containerView;
	UIView* drawerView = self.drawerView;
	UIView* shadowView = self.shadowView;
	UIView* backgroundView = self.backgroundView;
	UIView* contentView = self.contentView;

	if (!self.animationInProgress) {
		CGRect cellBounds = [cellView bounds];
        CGRect containerFrame = [containerView frame];

        containerFrame.size.height = cellBounds.size.height;
        containerFrame.size.width = cellBounds.size.width;

		if (self.drawerRevealed) {
			if (containerFrame.origin.x > cellBounds.origin.x) {
				containerFrame.origin.x = cellBounds.origin.x + cellBounds.size.width;
			}
			else {
				containerFrame.origin.x = cellBounds.origin.x - cellBounds.size.width;
			}

			[containerView setFrame:containerFrame];

			[containerView addSubview:backgroundView];
			[containerView addSubview:contentView];

			[self insertSubview:drawerView belowSubview:containerView];
			[self insertSubview:shadowView aboveSubview:drawerView];
		}
		else {
			[containerView setFrame:containerFrame];
			[containerView addSubview:backgroundView];
			[containerView addSubview:contentView];

			[self addSubview:containerView];
		}
	}

	// Move other subviews. E.g. drag reorder control
	for (UIView *subview in [self.subviews reverseObjectEnumerator]) {
		if (subview == containerView) {
			continue;
		}

		if (subview == drawerView) {
			continue;
		}

		if (subview == shadowView) {
			continue;
		}

		if (subview == backgroundView) {
			continue;
		}


		if (subview == contentView) {
			continue;
		}

		[containerView insertSubview:subview atIndex:0];
	}

	[drawerView setFrame:[cellView bounds]];

	[self updateShadowFrame];
}

- (void)updateShadowFrame
{
	UIView* cellView = self;
	CGRect cellBounds = [cellView bounds];
	UIView* containerView = self.containerView;
	UIView* shadowView = self.shadowView;
	CGRect containerFrame = [containerView frame];
	CGRect shadowFrame = containerFrame;

	shadowFrame.size.width *= 2.0;
    
	if (containerFrame.origin.x < cellBounds.origin.x) {
        shadowFrame.origin.x = containerFrame.origin.x + containerFrame.size.width;
	}
	else if (containerFrame.origin.x > cellBounds.origin.x) {
        shadowFrame.origin.x = containerFrame.origin.x - shadowFrame.size.width;
	}
    
	[shadowView setFrame:shadowFrame];
}

@end


static HHPanningCollectionViewCellDirection HHOppositeDirection(HHPanningCollectionViewCellDirection direction)
{
	switch (direction) {
		case HHPanningCollectionViewCellDirectionRight:
			return HHPanningCollectionViewCellDirectionLeft;
		case HHPanningCollectionViewCellDirectionLeft:
			return HHPanningCollectionViewCellDirectionRight;
	}
}
