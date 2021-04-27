package Functions is
    function NumberToCharacter(number:natural) return character;
end package Functions;

package body Functions is
    function NumberToCharacter(number:natural) return character is
        variable char : character;
    begin
        char := character'val(number + 48);
        return char;
    end NumberToCharacter;
end package body Functions;