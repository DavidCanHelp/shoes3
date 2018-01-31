#include "shoes/app.h"
#include "shoes/ruby.h"
#include "shoes/config.h"
#include "shoes/world.h"
#include "shoes/native/native.h"
#include "shoes/types/types.h"
#include "shoes/native/cocoa/listbox.h"
extern VALUE cTimer;

//#import <Carbon/Carbon.h>

#define HEIGHT_PAD 6

#define INIT    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init]
#define RELEASE [pool release]
#define COCOA_DO(statements) do {\
  INIT; \
  @try { statements; } \
  @catch (NSException *e) { ; } \
  RELEASE; \
} while (0)

// ---- Cocoa Object side ----

@implementation ShoesPopUpButton
- (id)initWithFrame: (NSRect)frame andObject: (VALUE)o
{
  if ((self = [super initWithFrame: frame pullsDown: NO]))
  {
    object = o;
    attrs = NULL;
    [self setTarget: self];
    [self setAction: @selector(handleChange:)];
  }
  return self;
}
-(IBAction)handleChange: (id)sender
{
  shoes_control_send(object, s_change);
}
@end

// ---- Ruby calls C/obj->C here ----

SHOES_CONTROL_REF
shoes_native_list_box(VALUE self, shoes_canvas *canvas, shoes_place *place, VALUE attr, char *msg)
{
  INIT;
  ShoesPopUpButton *pop = [[ShoesPopUpButton alloc] initWithFrame:
    NSMakeRect(place->ix + place->dx, place->iy + place->dy,
    place->ix + place->dx + place->iw, place->iy + place->dy + place->ih)
    andObject: self];
  
  pop->attrs = shoes_attr_dict(attr);
  
  // Tooltip
  VALUE vtip = shoes_hash_get(attr, rb_intern("tooltip"));
  if (! NIL_P(vtip)) {
    char *cstr = RSTRING_PTR(vtip);
    NSString *tip = [NSString stringWithUTF8String: cstr];
    [pop setToolTip:tip];
  } 

  RELEASE;
  return (NSControl *)pop;
}

void
shoes_native_list_box_update(SHOES_CONTROL_REF ref, VALUE ary)
{
  long i;
  ShoesPopUpButton *pop = (ShoesPopUpButton *)ref;
  INIT;
  if (pop->attrs) {
    // Need to use menu_items to set AttributedStrings
    // TODO: probably too complicated - but it works
    [pop removeAllItems];
    NSString *emptystr = @"";
    int icnt = RARRAY_LEN(ary);
    NSArray *itemAry = [pop itemArray]; 
    for (i = 0; i < icnt; i++) {
      VALUE msg_s = shoes_native_to_s(rb_ary_entry(ary, i));
      char *msg = RSTRING_PTR(msg_s);
      NSString *str = [NSString stringWithUTF8String: msg];
      NSAttributedString *astr = [[NSAttributedString alloc] initWithString: str
        attributes: pop->attrs];  
      //printf(stderr,"Colorize %s\n", msg); // C string
      [[pop menu] insertItemWithTitle: str action: nil
            keyEquivalent: @"" atIndex: i];
      itemAry = [pop itemArray];
      NSMenuItem *mitem = itemAry[i];
      [mitem setAttributedTitle: astr];
    }
  } else {
    [pop removeAllItems];
    for (i = 0; i < RARRAY_LEN(ary); i++) {
      VALUE msg_s = shoes_native_to_s(rb_ary_entry(ary, i));
      char *msg = RSTRING_PTR(msg_s);
      NSString *str = [NSString stringWithUTF8String: msg];
      [[pop menu] insertItemWithTitle: str action: nil
            keyEquivalent: @"" atIndex: i];
    }
  }
  RELEASE;
}

VALUE
shoes_native_list_box_get_active(SHOES_CONTROL_REF ref, VALUE items)
{
  NSInteger sel = [(ShoesPopUpButton *)ref indexOfSelectedItem];
  if (sel >= 0)
    return rb_ary_entry(items, sel);
  return Qnil;
}

void
shoes_native_list_box_set_active(SHOES_CONTROL_REF ref, VALUE ary, VALUE item)
{
  long idx = rb_ary_index_of(ary, item);
  if (idx < 0) return;
  COCOA_DO([(ShoesPopUpButton *)ref selectItemAtIndex: idx]);
}
