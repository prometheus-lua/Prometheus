local count = 0;
for i = 0, 100, 1 do
    local x = function()
        i = i + 1;
    end
    x();
end
print(count);