#include <iostream>
#include <cstdint>
#include <cctype>
#include <vector>
#include <string_view>
#include <unordered_set>
#include <cstring>
#include <optional>

const char * TEXT =
"var a: sint64 = 42 yes"
;



namespace tokenizer {

    enum class TokenKind {
        eof,
        identifier,
        number,
        symbol,
        keyword
    };

    struct Token {
        TokenKind kind;
        std::string_view value;
        size_t line = 0;
     
        size_t col = 0;
    };

    struct TokenStream {
        std::vector<Token> buff;
        std::string_view source;
        size_t index = 0;

        TokenStream(std::string_view src, std::vector<Token> tokens)
            : source(src), buff(std::move(tokens))
        {}
        
        Token peek() {
            if (index >= buff.size())
                return {
                    .kind = TokenKind::eof,
                    .value = "<eof>",
                };

            return buff[index];
        }

        Token eat() {
           if (index >= buff.size())
                return {
                    .kind = TokenKind::eof,
                    .value = "<eof>",
                };

            return buff[index++];
 
        }

        typedef size_t Checkpoint;

        Checkpoint newCheckpoint() { return index; }

        void gotoCheckpoint(Checkpoint k) { index = k; }

        void reset() { index = 0; }
    };



    constexpr std::string_view compounds[] = {
        "==",
        "!=",
        ">=",
        "<=",
        "=>",
        "<-",
        "->",
        "::",
        "..",
        
        "...",
        "===",
        "<=>",
        "<->",
    };

    static const std::unordered_set<std::string_view> keywords = {
        "var",
    };

    constexpr bool isNum(const char c) { return '0' <= c && c <= '9'; }

    constexpr bool isIdent(const char c) {
        return
            (c=='_')
            ||('a'<=c && c<='z')
            ||('A'<=c && c<='Z')
            ||('0'<=c && c<='9')
            ;
    }

    bool isWS(const char c) { return std::isspace(static_cast<unsigned char>(c)); }

    bool isCompound(std::string_view s) {
        for (auto c : compounds)
            if (c==s) return true;
        return false;
    }

    constexpr bool isNumChar(const char c) {
        //TEMP
        return isIdent(c) || c=='.';
    }



    TokenStream tokenize(const char * str) {
        std::vector<Token> r;

        size_t index = 0;

        size_t line = 0;
        size_t col = 0;

        auto peek = [&]()->char { return str[index]; };

        auto eat = [&]()->char {
            col++;
            return str[index++];
        };

        auto eats = [&](size_t n) {
            for (size_t i = 0; i < n; i++)
                eat();
        };

        auto skipWS = [&]()->bool {
            char c = peek();

            while(isWS(c)) {
                eat();
                if (c=='\n') {
                    line++;
                    col = 1;
                }
                c = peek();
            }

            return peek() != '\0';
        };

        auto push = [&](TokenKind kind, std::string_view value) {
            r.push_back({
                    .kind = kind,
                    .value = value,
                    .line = line,
                    .col = col
            });
        };

        while (skipWS()) {
            char c = peek();

            //preparser instructions
            if (c=='#')
            {
                //TEMP
                eat();
            }
            //quoted identifiers
            else if (c=='"')
            {
                eat();
                size_t start = index;
                size_t i = start;
                size_t lines = 0;

                for (char c = str[i]; c!='"'; c = str[++i])
                    if (c=='\n') lines++;
                    else if (c=='\\') i++;

                push(
                    TokenKind::identifier,
                    std::string_view(str+start, i-start)
                );

                line += lines;
                eats(i-start+1);
            }
            //quoted identifiers
            else if (c=='\'')
            {
                eat();
                size_t start = index;
                size_t i = start;
                size_t lines = 0;

                for (char c = str[i]; c!='\''; c = str[++i])
                    if (c=='\n') lines++;
                    else if (c=='\\') i++;

                push(
                    TokenKind::identifier,
                    std::string_view(str+start, i-start)
                );

                line += lines;
                eats(i-start+1);
            }
            //numbers
            else if (isNum(c))
            {
                size_t start = index;
                size_t i = start;

                while (isNumChar(str[i])) i++;

                auto value = std::string_view(str+start, i-start);

                push(TokenKind::number, value);

                eats(i-start); //nom nom
            }
            //keywords or identifiers
            else if (isIdent(c))
            {
                size_t start = index;
                size_t i = start;

                while (isIdent(str[i])) i++;

                auto value = std::string_view(str+start, i-start);

                if (keywords.find(value)!= keywords.end())
                    push(TokenKind::keyword, value);
                else
                    push(TokenKind::identifier, value);

                eats(i-start); //nom nom
            }
            //symbols
            else
            {
                auto three = std::string_view(str+index, 3);
                auto two = std::string_view(str+index, 2);
                auto one = std::string_view(str+index, 1);

                if (isCompound(three)) {
                    push(TokenKind::symbol, three);
                    eats(3);
                } else if (isCompound(two)) {
                    push(TokenKind::symbol, two);
                    eats(2);
                } else {
                    push(TokenKind::symbol, one);
                    eat();
                }
            }
        }

        return TokenStream(str, std::move(r));
    }



    //maybe support exponential notation with "p"
    constexpr int digitValue(char c) {

        if (isNum(c))
            return c - '0';

        if ('a'<=c && c<='f')
            return 10 + (c - 'a');

        if ('A'<=c && c<='F')
            return 10 + (c - 'A');

        return -1;
    }

    template<typename T> bool parseNum(std::string_view text, T& result) {
        
        uint8_t base = 10;
        size_t i = 0;

        if (text.size()>2 && text[0]=='0') switch (std::tolower(static_cast<unsigned char>(text[1]))) {
            case 'x': base =16; i = 2; break;
            case 'o': base = 8; i = 2; break;
            case 'q': base = 4; i = 2; break;
            case 'b': base = 2; i = 2; break;
        }

        T value = 0;
        T fraction = 0;
        T divisor = 1;

        bool dot = false;

        for (; i<text.size(); i++) {
            char c = text[i];

            if (c=='_') continue;

            if (c=='.') {
                if (dot) return false;

                dot = true;
                continue;
            }

            int digit = digitValue(c);

            if (digit<0 || digit>=base)
                return false;

            if (dot) {
                divisor *= base;
                fraction += static_cast<T>(digit) / divisor;
            } else
                value = value * base + digit;
        }

        result = value + fraction;
        return true;

    }

};



namespace ast {
    
};



int main(int argv, char ** argc) {
    std::cout<<"Hello, world!\n";
    
    auto tokens = tokenizer::tokenize(TEXT);

    double a;
    tokenizer::parseNum("0XF.8", a);
    std::cout<<'\n'<<a<<'\n';

    {
        char tmp;
        std::cout<<"enter anything to exit: ";
        std::cin>>tmp;
    }
    return 0;
}
