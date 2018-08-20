module Main where

import           Criterion.Main

import           Data.Text
import qualified Data.Vector                     as Vector
import qualified Data.Vector.Storable            as VectorStorable
import qualified Geography.VectorTile            as VectorTile

import qualified Data.Geometry.Clip              as Clip
import qualified Data.Geometry.MapnikVectorTile  as MapnikVectorTile
import qualified Data.Geometry.Types.Config      as Config
import qualified Data.Geometry.Types.Geography   as TypesGeography
import qualified Data.Geometry.Types.LayerConfig as LayerConfig
import qualified Data.Geometry.Types.Simplify    as TypesSimplify


main :: IO ()
main = do
    let tenPoly = simplePoly (50 :: Double) (10 :: Double)
        oneHundredPoly = simplePoly (50 :: Double) (100 :: Double)
        oneThousandPoly = simplePoly (50 :: Double) (1000 :: Double)
        tenThousandPoly = simplePoly (50 :: Double) (10000 :: Double)
        multiTenPoly = Vector.fromList(generateArrayPoly 1 tenPoly [])
        multiOneHundredPoly = Vector.fromList(generateArrayPoly 1 oneHundredPoly [])
        multiOneThousandPoly = Vector.fromList(generateArrayPoly 1 oneThousandPoly [])
        multiTenThousandPoly = Vector.fromList(generateArrayPoly 1 tenThousandPoly [])
    defaultMain [
                bgroup "writeFiles" [
                     bench "100 Points" $ nf (testPoly 100 boundBox tenPoly) [Nothing]
                ]
                ,
                bgroup "Clip Polygon"[
                        bgroup "Size 10"
                                [
                                        -- bench "10 Points" $ nf (testPoly 10 boundBox tenPoly) [Nothing]
                                 bench "100 Points" $ nf (testPoly 100 boundBox tenPoly) [Nothing]
                                , bench "1000 Points" $ nf (testPoly 1000 boundBox tenPoly) [Nothing]
                                , bench "10000 Points" $ nf (testPoly 10000 boundBox tenPoly) [Nothing]
                                ]
                        , bgroup "Size 100"
                                [ bench "10 Points" $ nf (testPoly 10 boundBox oneHundredPoly) [Nothing]
                                , bench "100 Points" $ nf (testPoly 100 boundBox oneHundredPoly) [Nothing]
                                , bench "1000 Points" $ nf (testPoly 1000 boundBox oneHundredPoly) [Nothing]
                                , bench "10000 Points" $ nf (testPoly 10000 boundBox oneHundredPoly) [Nothing]
                                ]
                        , bgroup "Size 1000"
                                [ bench "10 Points" $ nf (testPoly 10 boundBox oneThousandPoly) [Nothing]
                                , bench "100 Points" $ nf (testPoly 100 boundBox oneThousandPoly) [Nothing]
                                , bench "1000 Points" $ nf (testPoly 1000 boundBox oneThousandPoly) [Nothing]
                                , bench "10000 Points" $ nf (testPoly 10000 boundBox oneThousandPoly) [Nothing]
                                ]
                        , bgroup "Size 10000"
                                [ bench "10 Points" $ nf (testPoly 10 boundBox tenThousandPoly) [Nothing]
                                , bench "100 Points" $ nf (testPoly 100 boundBox tenThousandPoly) [Nothing]
                                , bench "1000 Points" $ nf (testPoly 1000 boundBox tenThousandPoly) [Nothing]
                                , bench "10000 Points" $ nf (testPoly 10000 boundBox tenThousandPoly) [Nothing]
                                ]
                ],bgroup "Clip MultiPolygon "[
                        bgroup "Size 10"
                                [ bench "10 Points" $ nf (testPolys 10 boundBox multiTenPoly) []
                                , bench "100 Points" $ nf (testPolys 100 boundBox multiTenPoly) []
                                , bench "1000 Points" $ nf (testPolys 1000 boundBox multiTenPoly) []
                                , bench "10000 Points" $ nf (testPolys 10000 boundBox multiTenPoly) []
                                ]
                        , bgroup "Size 100"
                                [ bench "10 Points" $ nf (testPolys 10 boundBox multiOneHundredPoly) []
                                , bench "100 Points" $ nf (testPolys 100 boundBox multiOneHundredPoly) []
                                , bench "1000 Points" $ nf (testPolys 1000 boundBox multiOneHundredPoly) []
                                , bench "10000 Points" $ nf (testPolys 10000 boundBox multiOneHundredPoly) []
                                ]
                        , bgroup "Size 1000"
                                [ bench "10 Points" $ nf (testPolys 10 boundBox multiOneThousandPoly) []
                                , bench "100 Points" $ nf (testPolys 100 boundBox multiOneThousandPoly) []
                                , bench "1000 Points" $ nf (testPolys 1000 boundBox multiOneThousandPoly) []
                                , bench "10000 Points" $ nf (testPolys 10000 boundBox multiOneThousandPoly) []
                                ]
                        , bgroup "Size 10000"
                                [ bench "10 Points" $ nf (testPolys 10 boundBox multiTenThousandPoly) []
                                , bench "100 Points" $ nf (testPolys 100 boundBox multiTenThousandPoly) []
                                , bench "1000 Points" $ nf (testPolys 1000 boundBox multiTenThousandPoly) []
                                , bench "10000 Points" $ nf (testPolys 10000 boundBox multiTenThousandPoly) []
                                ]
                ]
                ]


testPoly :: Integer -> TypesGeography.BoundingBoxPts -> VectorTile.Polygon -> [Maybe VectorTile.Polygon] -> [Maybe VectorTile.Polygon]
testPoly 0 _ _ d = d
testPoly a b c d = d ++ testPoly (a - 1) b c [Clip.clipPolygon b c]

testPolys :: Integer -> TypesGeography.BoundingBoxPts -> Vector.Vector VectorTile.Polygon -> [Vector.Vector VectorTile.Polygon] -> [Vector.Vector VectorTile.Polygon]
testPolys 0 _ _ d = d
testPolys a b c d = d ++ testPolys (a - 1) b c [Clip.clipPolygons b c]

generateArrayPoly :: Integer -> VectorTile.Polygon -> [VectorTile.Polygon] -> [VectorTile.Polygon]
generateArrayPoly 0 _ c = c
generateArrayPoly a b c = c ++ generateArrayPoly (a - 1) b [b]

simplePoly :: (Floating a, RealFrac a) => a -> a -> VectorTile.Polygon
simplePoly radius total = VectorTile.Polygon (VectorStorable.fromList (getPoints radius total)) (Vector.fromList [])

getPoints :: (RealFrac a, Floating a) => a -> a -> [VectorTile.Point]
getPoints radius total = getPoints' radius total total []

getPoints' :: (RealFrac a, Floating a) => a -> a -> a -> [VectorTile.Point] -> [VectorTile.Point]
getPoints' _ 0 _ b = b
getPoints' radius current total b = b ++ getPoints' radius (current - 1) total [getCoord radius current total]

getCoord :: (RealFrac a, Floating a) => a -> a -> a -> VectorTile.Point
getCoord radius current total = VectorTile.Point (round $ getX radius current total)  (round $ getY radius current total)

getX :: (RealFrac a, Floating a) => a -> a -> a -> a
getX radius current total = radius * sin ((360 / total) * current)

getY :: (RealFrac a, Floating a) => a -> a -> a -> a
getY radius current total = radius * cos ((360 / total) * current)

boundBox :: TypesGeography.BoundingBoxPts
boundBox = TypesGeography.BoundingBoxPts (VectorTile.Point 0 0) (VectorTile.Point 1 1)

testConf :: Config.Config
testConf = Config.mkConfig (pack "demo") 15 (28999,19781) 128 2048 1 TypesSimplify.NoAlgorithm

smallFC :: LayerConfig.LayerConfig
smallFC = LayerConfig.LayerConfig "./test/integration/small.json" "./dump/small.mvt" (pack "demo") 15 28999 19781 128 2048 1 TypesSimplify.NoAlgorithm

testMain :: IO ()
testMain = MapnikVectorTile.writeLayer smallFC
