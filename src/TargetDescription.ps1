function Describe-Target {
    param([object]$Op)
    $valueKind = ''
    if ($Op.Kind -eq 'Registry') { $valueKind = $Op.ValueKind }
    return [ordered]@{
        kind=$Op.Kind; path=$Op.Path; name=$Op.Name
        valueKind=$valueKind; desired=$Op.Value
    }
}
