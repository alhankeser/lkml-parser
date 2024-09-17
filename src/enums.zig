pub const ValueKind = enum {
    UnQuoted,
    Quoted,
    Sql,
};

pub const TokenKind = enum {
    Key,
    Value,
    Control,
};

pub const Char = enum {
    Colon,
    SemiColon,
    ListOpen,
    ListClose,
    Comma,
    ObjectOpen,
    ObjectClose,
    Quote,
    Space,
    NewLine,
    Comment,
    NotSpecial,
    EOF,
    SOF,
};

pub const State = enum {
    Done,
    SeekKey,
    ReadKey,
    SeekValue,
    ReadSqlValue,
    ReadUnquotedValue,
    ReadQuotedValue,
    ReadComment,
    ReadControlChar,
    NotStarted,
};