$count = [1,2,3,4,5]
$sum = reduce($count) | $total, $i | { notice("total => $total") ; $total + $i }

notice("total is $total & i is $i")
notice("Sum is $sum")
