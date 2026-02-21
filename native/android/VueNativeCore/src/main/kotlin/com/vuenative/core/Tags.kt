package com.vuenative.core

/** View tag IDs used with View.setTag(id, value) */
object Tags {
    const val FLEX_PROPS    = 0x7F_FF_0001
    const val EVENT_HANDLER = 0x7F_FF_0002
    const val NODE_ID       = 0x7F_FF_0003
    const val FACTORY       = 0x7F_FF_0004
    const val BORDER_COLOR  = 0x7F_FF_0010
    const val BORDER_WIDTH  = 0x7F_FF_0011
    const val GAP           = 0x7F_FF_0012
}

/** Alias used throughout the codebase */
const val TAG_FLEX_PROPS    = Tags.FLEX_PROPS
const val TAG_EVENT_HANDLER = Tags.EVENT_HANDLER
const val TAG_NODE_ID       = Tags.NODE_ID
const val TAG_FACTORY       = Tags.FACTORY
const val TAG_BORDER_COLOR  = Tags.BORDER_COLOR
const val TAG_BORDER_WIDTH  = Tags.BORDER_WIDTH
const val TAG_GAP           = Tags.GAP
